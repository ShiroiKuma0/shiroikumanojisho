# FFmpeg/FFprobe invocation audit — shiroikumanojisho (flutter_ffmpeg 0.4.2 → ffmpeg_kit_flutter_new 4.5.x)

Current native package: `flutterFFmpegPackage = "full-gpl-lts"` (`/home/shiroikuma/git/shiroikuma-jisho/android/build.gradle:43`).
Dart dependency: `flutter_ffmpeg: ^0.4.2` (`pubspec.yaml:50`).

Exactly five Dart files import `package:flutter_ffmpeg/flutter_ffmpeg.dart`; there are no other call sites in `lib/` (all other grep hits for "ffmpeg" are comments, `getFfmpegTimestamp` helpers, or user-facing shell-snippet text in `reader_audio_toolbar.dart` which is display-only, never executed by the app).

Note the actual paths differ from the ones given in the task:
- `lib/src/utils/player/subtitle_utils.dart` (not `lib/src/utils/subtitle_utils.dart`)
- `lib/src/media/source_types/player_media_source.dart` (not `sources/`)
- `lib/src/utils/ocr/subtitle_ocr.dart` (not `lib/src/utils/subtitle_ocr.dart`)

---

## Invocation sites

### 1. `lib/src/utils/player/subtitle_utils.dart`

#### 1a. `SubtitleUtils.targetSubtitleFromVideo` — lines 133–144
Command template:
```
-loglevel quiet -i "<videoPath>" -map 0:m:language:<threeLetterCode> -map -0:a -map -0:v "<appDocDir>/targetSubtitles/extractSrt.srt"
```
- Purpose: demux all subtitle tracks tagged with the target language from a local video (typically MKV) and transcode them to a single SRT.
- Components: matroska/mp4/etc. demuxers; text-subtitle decoders (`subrip`, `ass`, `ssa`, `mov_text`, `webvtt`); `subrip` encoder; `srt` muxer; `file` protocol. All native.
- API: `FlutterFFmpeg().execute(command)`. Result validated by output-file content, not return code.

#### 1b. `SubtitleUtils.subtitlesFromVideo` — lines 201–216
Command template (looped per subtitle-stream ordinal `i`, image-based tracks skipped via `skipIndexes`):
```
-loglevel quiet -i "<videoPath>" -map 0:s:<i> "<appDocDir>/subtitles/extractSrt<i>.srt"
```
- Purpose: per-track extraction of embedded text subtitles to SRT.
- Components: same as 1a.
- API: `FlutterFFmpeg().execute(command)` + `FlutterFFmpegConfig().getLastCommandOutput()` — the log text is parsed for `"Stream map '0:s:<i>' matches no streams."` to terminate the loop. **Migration note:** ffmpeg-kit exposes per-session output (`session.getOutput()` / `getAllLogsAsString()`), not a global last-command log; the sentinel-string parse must move to the session object.

#### 1c. `SubtitleUtils.convertAssSubtitles` — lines 250–254
Command template:
```
-i "<inputPath>" "<appDocDir>/subtitles/assSubtitles.srt"
```
- Purpose: convert an external `.ass`/`.ssa` subtitle file to SRT.
- Components: `ass` demuxer + decoder; `subrip` encoder; `srt` muxer; `file` protocol. All native.
- API: `FlutterFFmpeg().execute(command)`.

### 2. `lib/src/media/source_types/player_media_source.dart`

#### 2a. `PlayerMediaSource.generateImages` — lines 170–176
Command template (looped per subtitle):
```
-ss <hh:mm:ss.SSS> -y -i "<inputPath>" -frames:v 1 -q:v 2 "<appSupportDir>/playerImagePreview/<ts>/previewImage<index>.jpg"
```
- `inputPath` is `item.mediaIdentifier` (local file) **or, for `PlayerYoutubeSource`, an https googlevideo.com stream URL** via `source.getDataSource(item)` (`player_youtube_source.dart:536`).
- Purpose: extract a single JPEG frame per subtitle for the Anki-card creator image field.
- Components: matroska/mp4/webm demuxers; video decoders (`h264`, `hevc`, `vp9`, `mpeg4`, …, all native — decoding H.264 does NOT need x264); `mjpeg` encoder; `image2` muxer; auto-inserted `scale`/`format` filter for yuvj conversion; `file` + `https`/`tls` protocols.
- API: `FlutterFFmpeg().execute(command)` + `FlutterFFmpegConfig().getLastCommandOutput()` — parsed for `'Output file is empty, nothing was encoded'`.

#### 2b. `PlayerMediaSource.generateAudio` — lines 264–268
Command template:
```
-ss <start> -to <end> -y -i "<inputPath>" -map 0:a:<audioIndex> "<appSupportDir>/playerAudioPreview/previewAudio.mp3"
```
- `inputPath` is a local file **or, for YouTube, an https audio-stream URL** via `getAudioExportUrl` (`player_youtube_source.dart:572`).
- Purpose: clip the subtitle's audio span to MP3 for the Anki-card audio field (`getAudioPreviewFile`, `app_model.dart:3140`, hardcodes `.mp3`; the export copy at `getAudioExportFile` is a plain file copy, no second ffmpeg run).
- Components: demuxers as above; audio decoders (`aac`, `opus`, `vorbis`, `mp3`, `ac3`, `eac3`, `flac`, `pcm_*` — all native); **`libmp3lame` encoder (external library)**; `mp3` muxer; `aresample` implicit; `file` + `https`/`tls` protocols.
- API: `FlutterFFmpeg().execute(command)`.

### 3. `lib/src/media/sources/player_local_media_source.dart`

#### `PlayerLocalMediaSource.generateThumbnail` — lines 100–118
Command template (first at 30 s, retried at 1 s if output empty):
```
-ss <timestamp> -y -i "<inputPath>" -frames:v 1 -q:v 2 "<targetPath>"    # targetPath = thumbnail.jpg
```
- Purpose: JPEG thumbnail for picked/downloaded videos. Also called by `PlayerYoutubeOfflineSource.prepareThumbnail` (`player_youtube_offline_source.dart:129`) — always a **local** file path in both callers.
- Components: same as 2a minus network protocols.
- API: `FlutterFFmpeg().execute(command)` + `FlutterFFmpegConfig().getLastCommandOutput()` — parsed for `'Output file is empty, nothing was encoded'` to trigger the 1-second retry.

### 4. `lib/src/utils/ocr/subtitle_ocr.dart`

#### 4a. `SubtitleOcr.detectImageTracks` — lines 94–96
- `FlutterFFprobe().getMediaInformation(videoPath)` on a **local** file; iterates `information.getStreams()`, reads `getAllProperties()` for `codec_type`, `codec_name` (`hdmv_pgs_subtitle` / `dvd_subtitle`), and `tags.language` / `tags.title`.
- Purpose: probe for image-based subtitle tracks to offer OCR.
- Components: ffprobe binary + demuxers only; no codecs. `file` protocol.
- API: **`FlutterFFprobe.getMediaInformation`** — in ffmpeg-kit this becomes `FFprobeKit.getMediaInformation` and the property-map access changes shape (`MediaInformationSession.getMediaInformation()`, `StreamInformation.getAllProperties()`); the biggest structural rewrite of the migration alongside the last-command-output changes.

#### 4b. `SubtitleOcr.ocrTrack` — lines 160–162
Command template:
```
-loglevel quiet -i "<videoPath>" -map 0:s:<subtitleOrdinal> -c:s copy "<appDocDir>/ocrSubtitles/extract.sup"
```
- Purpose: stream-copy a PGS track out of an MKV to a `.sup` for the ML Kit OCR pipeline (VobSub route is explicitly unsupported — throws before any ffmpeg call).
- Components: matroska demuxer; **no decoder/encoder** (`-c:s copy`); `sup` (PGS) muxer — native; `file` protocol.
- API: `FlutterFFmpeg().execute(command)`; success validated by output-file existence/length.

### 5. `lib/src/pages/implementations/player_source_page.dart`

No `execute` calls — statistics-callback plumbing only:
- `_trackFfmpegProgress` (lines 977–990): `FlutterFFmpegConfig().enableStatisticsCallback((statistics) {...})`, reads `statistics.time` (processed ms) to render a percent banner during the embedded-subtitle scan (drives the runs from §1a/1b).
- `_clearFfmpegProgress` (lines 993–996): `enableStatisticsCallback(null)`.
- `ocrImageSubtitleTrack` (lines 3970–3975, cleared at 4008): same pattern, progress for the §4b demux pass.
- **Migration note:** ffmpeg-kit has no global statistics callback toggled by config; statistics arrive per-session (callback passed to `FFmpegKit.executeAsync`) or via `FFmpegKitConfig.enableStatisticsCallback` with `statistics.getTime()`. Since the callbacks here are enabled around `execute` calls made in *other* files, the global `FFmpegKitConfig.enableStatisticsCallback` is the drop-in equivalent; passing `null` to disable is still supported.

## flutter_ffmpeg API surface used (complete)

| API | Sites | ffmpeg-kit equivalent |
|---|---|---|
| `FlutterFFmpeg().execute(String)` | 1a, 1b, 1c, 2a, 2b, 3, 4b | `FFmpegKit.execute` (sync sessions fine; commands are single-quoted-string style, parsed identically) |
| `FlutterFFmpegConfig().getLastCommandOutput()` | 1b, 2a, 3 | `session.getOutput()` / `session.getAllLogsAsString()` — must be read from the session returned by the same `execute`, which means the execute call and the log parse must be co-located (currently 2a/3 already are; 1b is too) |
| `FlutterFFmpegConfig().enableStatisticsCallback(cb/null)` | 5 (×2 enable, ×2 disable) | `FFmpegKitConfig.enableStatisticsCallback` (global) — field access becomes `statistics.getTime()` |
| `FlutterFFprobe().getMediaInformation(path)` | 4a | `FFprobeKit.getMediaInformation` + new accessor shapes |

Not used anywhere: `executeWithArguments`, `executeAsync`, `cancel`, `getExternalLibraries`, log callbacks, `setFontDirectory`, pipes.

## Union of required components

- **Demuxers:** matroska/webm, mov/mp4/m4a, avi, mpegts and friends (whatever containers users open), `ass`, `srt`; all native.
- **Decoders:** video — `h264`, `hevc`, `vp9`, `mpeg4`, etc. (native ffmpeg decoders); audio — `aac`, `opus`, `vorbis`, `mp3`, `ac3`, `eac3`, `flac`, `pcm_*` (native); subtitles — `subrip`, `ass`, `ssa`, `mov_text`, `webvtt` (native).
- **Encoders:** `mjpeg` (native), `subrip` (native), **`libmp3lame` (external, LGPL)** — the only external library actually exercised.
- **Muxers:** `image2`, `mp3`, `srt`, `sup` (PGS); all native.
- **Protocols:** `file`, **`http`/`https`/`tls`** (YouTube googlevideo stream URLs fed to §2a and §2b — `PlayerYoutubeSource` is registered and active, `app_model.dart:1121`).
- **Filters:** none explicit; only auto-inserted `scale`/`format`/`aresample`.
- **ffprobe** binary (media information).

## GPL analysis

**No GPL-only component is used.** x264/x265/xvid are H.264/H.265/MPEG-4 *encoders*; the app only *decodes* those codecs (native LGPL decoders) and encodes nothing but single-frame MJPEG, SRT text, and MP3. vid.stab is unused. The current `full-gpl-lts` selection is strictly overkill — **`full` (LGPL) suffices**.

## Minimal variant verdict

Per the ffmpeg-kit variant matrix:
- `min` — fails: no lame, no TLS.
- `https` (min + gnutls) — fails: no `libmp3lame` for the Anki MP3 clip.
- `audio` (lame/shine/opus/vorbis…) — fails: no gnutls, so YouTube https inputs break.
- `video` — fails: neither lame nor gnutls.
- **`full` (audio + video + https, LGPL) — the minimal published variant that covers everything.** Needed pieces from it: `libmp3lame` + gnutls; the video-package libs (freetype/libass/libwebp…) come along unused but there is no smaller combination offered.
- `full_gpl` — not needed.

If YouTube support were ever dropped (making all ffmpeg inputs local files), `audio` would become the minimal variant; if MP3 export were switched to AAC (`.m4a`, native `aac` encoder), `https` would suffice. As the code stands today: **`full`**.

## Network-protocol answer

Yes — https URLs reach ffmpeg in exactly two places, both in `player_media_source.dart`: `generateImages` (YouTube video stream URL) and `generateAudio` (YouTube audio stream URL). Every other invocation (subtitle extraction ×3, PGS demux, thumbnail, ffprobe) operates on local files only; `initialiseEmbeddedSubtitles` explicitly skips the ffmpeg pass for non-file data sources (`player_source_page.dart:1000`).

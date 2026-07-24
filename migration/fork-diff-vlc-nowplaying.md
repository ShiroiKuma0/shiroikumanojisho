# Fork audit: flutter_vlc_player and nowplaying

Audited 2026-07-24 for the toolchain migration of `shiroikuma-jisho`. Clones live under
`/tmp/claude-1000/-home-shiroikuma-git-shiroikuma-jisho/f5bf7dc6-92d2-41c4-831f-6f334fe07e81/scratchpad/forkaudit/{vlc,nowplaying}`
with `upstream` remotes added, in case further diffing is wanted.

---

## Fork 1: flutter_vlc_player (arianneorpilla/flutter_vlc_player @ 013632b)

### Base version

- Merge-base with upstream (`solid-software/flutter_vlc_player`): `4856caa98da72c38be3683fe7d2106fdfade1331`
  ("Merge pull request #404 from pinpong/gradle").
- `git describe`: **7.2.0-18-g4856caa** — i.e. the fork branched from upstream master **18 commits after the 7.2.0 tag, before 7.3.0**. Effectively a 7.2.x-dev base.

### Fork-only commits (merge-base..013632b)

| Commit | Description | Verdict |
|---|---|---|
| `3da05b6` "added allowBackgroundPlayback" (author pinpong) | Adds `allowBackgroundPlayback` flag to all three `VlcPlayerController` constructors; skips creating `VlcAppLifeCycleObserver` when true (so the player is not paused on backgrounding). Plus incidental reformatting noise. | **Obsolete in 7.4.4.** This exact commit `3da05b6` is literally in upstream 7.4.4's history (merged via upstream PR #520, shipped in 7.4.0). Upstream 7.4.4 has `allowBackgroundPlayback` on `.asset`/`.network` (default `false`) and `.file` (default **`true`** — note the changed default for `.file`). |
| `667c7f7` "Force OpenSLES to fix audio cut" | Unconditional `mediaPlayer.setAudioOutput("opensles")` in `FlutterVlcPlayer.java` `setupVlcMediaPlayer()`. | Superseded by `460851a` below; historical only. |
| `460851a` "opensles option" | Refines the above: `setAudioOutput("opensles")` is called only when the LibVLC options list contains `--aout=opensles`. Net Java diff vs upstream is ~6 lines in `FlutterVlcPlayer.java`. | **Behavior customization to preserve.** Upstream 7.4.4 has **no** `setAudioOutput`/opensles handling anywhere in the Android code. The app actively uses this: `player_use_opensles` preference **defaults to `true`** (`lib/src/models/app_model.dart:4713`) and all three player sources pass `--aout=opensles` when it's on (`player_youtube_source.dart:369`, `player_local_media_source.dart:318`, `player_network_stream_source.dart:158`). Passing the option to `new LibVLC(context, options)` alone is not what the fork relied on — the commit history ("Force OpenSLES to fix audio cut") shows the explicit `MediaPlayer.setAudioOutput` call was needed to actually take effect. |
| `013632b` merge commit | Also bumps `solid_lints 0.0.14 → 0.0.16` in both pubspecs (dev dependency). | Trivial, obsolete. |

Net effective fork diff vs merge-base: only `vlc_player_controller.dart` (obsolete), `FlutterVlcPlayer.java` (the opensles hook), and two dev-dependency lines. Nothing else was patched — no pigeon/platform-interface changes, no iOS changes.

### App API compatibility with 7.4.4

- `VlcPlayerController`, `getSpuTracks`, `setSpuTrack` all present in 7.4.4 (`vlc_player_controller.dart:618-640` area). No removal risk found.
- Upstream 7.4.4 Android: `namespace = "software.solid.fluttervlcplayer"` declared, `compileSdk 35`, `minSdk 21`, libvlc `3.6.3` (fork was on `3.6.0-eap2`). AGP-8-ready.
- Caveat: the original "audio cut" bug motivating OpenSLES was against libvlc 3.6.0-eap2; libvlc 3.6.3 may have fixed the AudioTrack issue, but there is no evidence either way — do not silently drop the option.

### Recommendation

**Migrate to upstream 7.4.4, re-applying one small patch.** Of the two real patches, one (background playback) is upstream verbatim; the other (opensles) is a self-contained ~6-line hook in `setupVlcMediaPlayer()` in `FlutterVlcPlayer.java`. Options:

1. Preferred: fork/vendor upstream 7.4.4 and cherry-pick the `460851a` hunk onto it (it applies almost cleanly — 7.4.4's `setupVlcMediaPlayer()` at lines 125-138 is byte-identical to the fork's pre-patch shape).
2. Alternatively test 7.4.4 stock with `--aout=opensles` as a plain LibVLC option on the Boox Palma 2 Pro; if audio is clean, the patch can be dropped — but that must be an on-device test, not an assumption.

Watch item: 7.4.4 defaults `allowBackgroundPlayback: true` for `VlcPlayerController.file(...)`. The app passes it explicitly from `appModel.playerBackgroundPlay` at every construction site, so behavior is unchanged, but any future call site that omits it gets background playback on local files.

---

## Fork 2: nowplaying (arianneorpilla/nowplaying @ 290ee10)

### Upstream identity

- Upstream is **`https://github.com/shinyford/nowplaying`** (declared in the fork's own `pubspec.yaml` `repository:` field; the pub package `nowplaying` is by shinyford — the "nicsford" guess was close but wrong).
- Upstream status: **alive but dormant.** Last commit `aabf013` on 2024-05-23 ("Typo and tidying"), version 3.0.3. Nothing in ~26 months.

### Base version

- Merge-base: `6285d77` = upstream **v2.0.6**. The fork is v2.0.6 plus four commits.

### Fork-only commits (6285d77..290ee10)

| Commit | Description | Verdict |
|---|---|---|
| `ac9442c` chore: Update pubspec.lock | Lockfile refresh only. | Irrelevant. |
| `198f2ef` chore: Update idea files | IDE metadata only. | Irrelevant. |
| `6e9b14d` build(android): Bump gradle plugin, minSdkVersion | `android/build.gradle`: jcenter→mavenCentral, AGP classpath 3.5.0→3.5.4, minSdkVersion 16→21. | Housekeeping; mostly moot under a modern app-level AGP, but the jcenter removal matters (jcenter is dead). Upstream master still has jcenter + minSdk 16. |
| `290ee10` fix(android): NowPlayingListenerService NullPointerException | The one real patch, in `android/src/main/java/com/gomes/nowplaying/NowPlayingListenerService.java`: (a) null-guards `controller.getPlaybackState()` before `.getState()` (NPE crash when a media notification has no playback state yet); (b) guards `sbn.getNotification().getSmallIcon()` behind `SDK_INT >= M`; (c) minor cleanups (`static class SbnAndToken`, drop redundant cast). | **Behavior customization to preserve — a crash fix.** |

### Does upstream's current state cover the patches?

**No.** Upstream master (v3.0.3) still has the unguarded `controller.getPlaybackState().getState()` at `NowPlayingListenerService.java:60` and the unguarded `getSmallIcon()` at line 93 — the NPE fix was never upstreamed. Also, upstream v3.0.0 was a substantial rework (Spotify support, `lib/` split into `nowplaying_track.dart`, `nowplaying_spotify_controller.dart`, `resolvers/*`), so moving to upstream is an API migration that *loses* the crash fix. The app's usage surface (`NowPlaying.instance.stream/.start()/.requestPermissions()/.track` and `NowPlayingTrack` in `reader_lyrics_source.dart` / `reader_lyrics_page.dart`) would likely still compile against v3, but there is nothing in v3 worth that churn (Spotify support is unused).

### Namespace check (AGP 8+)

- The fork's `android/build.gradle` has **no `namespace` declaration** (checked at HEAD 290ee10: `android { compileSdkVersion 29; defaultConfig { minSdkVersion 21 } ... }` — no namespace line). **A namespace patch will be required for AGP 8+ regardless.**
- Upstream added exactly this in `b29e2fc` "Fixed Gradle build error: Added missing namespace to build.gradle (#18)": `namespace 'com.gomes.NowPlaying'` — a one-line cherry-pick candidate. Note upstream used `com.gomes.NowPlaying` (matches `AndroidManifest.xml` package); keep that exact string so R-class/manifest references stay consistent.

### Recommendation

**Keep the fork and patch it.** Upstream is dormant, never absorbed the NPE fix, and its v3 rework adds nothing the app uses. Required fork patches for the toolchain migration:

1. Add `namespace 'com.gomes.NowPlaying'` to `android { }` in `android/build.gradle` (mirror upstream `b29e2fc`).
2. While in there: raise `compileSdkVersion` from 29 (AGP 8 pairs with compileSdk 33+; align with whatever the migration standardizes on) and drop/modernize the plugin-local `buildscript { classpath AGP 3.5.4 }` block if the new toolchain chokes on it.
3. Keep `290ee10` (NPE fix) as-is — it is the fork's raison d'être.

---

## Summary table

| Fork | Based on | Real patches | Upstream covers them? | Recommendation |
|---|---|---|---|---|
| flutter_vlc_player | upstream master @ 7.2.0+18 (pre-7.3.0) | allowBackgroundPlayback; opensles `setAudioOutput` hook | Background playback: yes (7.4.0, same commit). OpenSLES hook: **no** | Move to upstream 7.4.4 + re-apply the ~6-line opensles Java hook (or prove on-device it is no longer needed) |
| nowplaying | shinyford/nowplaying v2.0.6 | NPE crash fix in NowPlayingListenerService; jcenter/minSdk housekeeping | **No** (upstream dormant since 2024-05, fix never landed; v3 is an unrelated Spotify rework) | Keep fork; add missing `namespace 'com.gomes.NowPlaying'` + compileSdk bump for AGP 8 |

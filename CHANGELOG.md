# Changelog

All notable user-visible changes to **白い熊の辞書 (shiroikumanojisho)** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **The reader's pull-up sheets — the toolbar's options (`⋮`) and
  navigate-to menus — now draw a yellow line along their top edge.**
  Both are black and slide up over a black reader page, so nothing
  marked where the page ended and the menu began: the rows read as if
  they were part of the text. The line uses the reader's own yellow,
  matching the rest of the sheets' palette. The player's sheets were
  already bounded — `JidoujishoBottomSheet` draws a full yellow border
  around itself in dark mode — so this brings the reader in line with
  them.

## [1.5.0+016] - 2026-08-19

### Fixed

- **Importing a book no longer replaces the one already in the
  library that happens to share its title.** ッツ identifies books by
  title alone: it looked the incoming `dc:title` up, found a match,
  and rewrote *that* record in place — so the new book took over the
  old one's library entry, and, because bookmarks are keyed to the
  record rather than the book, its reading position too. The old book
  was simply gone, with nothing said about it. Two translations of the
  same novel carry the same `dc:title`, which is how this surfaced:
  importing the second one produced a single shelf tile, both halves
  of a split view showing the same text, and a translation book that
  could not be attached to anything because it *was* the primary.

  Imports now insert instead of replacing, and the newcomer's library
  entry is labelled so the two can be told apart — by the language the
  EPUB declares (`Lázár` and `Lázár [cs]`), or by a counter
  (`Lázár (2)`) when it declares none or the tagged name is itself
  taken. A short message names both titles when this happens.

  The EPUB file is never modified: the label exists only as the title
  of ッツ's library entry. This also settles the knock-on problems,
  since per-book state — the translation-book association, split
  ratio, font size, per-book reader settings — is keyed by title and
  so was shared between same-titled books as well. Applies to both
  import buttons and to ッツ's own.

## [1.5.0+015] - 2026-08-17

### Added

- **All books** — a merged shelf at the top of the Reader source
  picker holding every imported book at once: EPUBs from the ッツ
  reader, scanned PDFs and mokuro manga volumes, ordered by what was
  read last, with never-opened books settling after. Each tile is
  badged with the icon of the source it came from, and opens with
  that source. The shelf imports nothing itself — importing stays
  with the individual sources — so its bar carries no add button.
- **All videos** — the same for the Player tab: local video files and
  downloaded YouTube videos in one list, last-played first, each row
  naming its source. Streamed sources (YouTube search, network
  streams) are not on the device and stay in their own tabs.

- **Delete** on the long-press dialog for books held in the ッツ
  library. Clearing only forgot the history row, which did nothing
  for an EPUB — the book stayed in the library and came straight back
  on the shelf. Delete (confirmed first, red, not undoable) removes
  the book from TTU's IndexedDB along with its bookmarks, this app's
  history row, and every per-book setting: attached audio,
  translation-book association, split ratio, per-book reader
  settings. Purging that last group is what makes a re-import of the
  same file come back clean — per-book state is keyed by title, so it
  would otherwise be inherited by the new copy.

- Separate dictionary fonts for **heading**, **entry** and
  **translation**, on the 白い熊 辞書 UI page under a new
  **Dictionary** section, alongside the two sizes. "Entry" is a
  definition written in the target language (a 国語辞典); "translation"
  is a gloss in another one (JMdict and other bilingual
  dictionaries). Which applies is decided per entry from its own
  text, since the import formats record which language a dictionary
  *applies to* but never which language it explains it in. All three
  share the UI page's font list and its "Import font…" action.

### Changed

- The current source is now shown as a **centred pill** — its name and
  icon in bold, ringed by a rounded border in the UI theme's colours —
  instead of grey hint text at the left edge of the bar, which was
  easy to read past. Tapping the pill opens the source picker; the
  source's own open action (file picker, library manager, browser)
  moved onto the leading icon beside it.
- Every source was renamed to say what it reads or plays: **EPUB
  reader (ッツ)**, **PDF reader**, **Manga reader (mokuro)**, **Web
  browser**, **Song lyrics**, **ChatGPT chat**, **Clipboard text**,
  **WebSocket text**; **Local video files**, **Downloaded YouTube**,
  **YouTube search**, **Network stream**. The Reader picker is
  reordered to match: All books, EPUB, PDF, manga, then the rest.
- Each Player source's tab now lists only its own videos. Every one of
  them used to show the entire player history, so switching source
  changed nothing on screen; the merged view is now **All videos**.
- The add button and the Anki card creator swapped places. The app
  bar's second slot now carries the active Reader source's add action
  — Scanned PDF its PDF import, ッツ Ebook Reader its EPUB import,
  mokuro its file picker — so adding a book is one reach from the top
  of the screen and always matches the selected source. The source bar
  below keeps its other actions (tweaks, catalogue, open link, TTU
  settings, manager). Reader sources with nothing to add (browser,
  clipboard, ChatGPT, WebSocket, lyrics) and the Player and Dictionary
  tabs leave the slot empty.
- The Anki card creator button is now **hidden by default**. It moved
  from the app bar to the end of the media source bar; switch it back
  on with "Anki card creator button" under **Toolbars** on the 白い熊
  辞書 UI page (preference key `show_card_creator_button`). The
  creator itself is unchanged and still reachable from dictionary
  results and the quick actions.
- Dev build counters are zero-padded to three digits — `1.5.0+008`
  in the title bar and in the APK filename — so builds sort in order
  in a file manager. Releases are unaffected: still bare `X.Y.Z`.
- **Entry and translation now have separate font sizes**, not just
  separate fonts — three sliders on the UI page (heading, entry,
  translation). An unset translation size follows the entry size, so
  nothing changes until you move it, and the left-edge swipe gesture
  scales all three together, each keeping its proportion.
- The word you tap in a book, a manga page or a web page highlights
  **black on yellow** instead of white on translucent red — the last
  red left inside the reader itself.
- The dictionary popup over a book now has a border, in the same
  colour and corner radius as dialogs (both settable on the UI page),
  so it reads as a panel over the text rather than a hole in it.
- **The accent colour is yellow now, not red.** Red was the shipped
  default and it drove switches, sliders, focus underlines, progress
  spinners, the selected navigation item and the video position bar —
  a splash of red on every black-and-yellow screen. Installs still on
  that default are moved to the theme's yellow once; an accent you
  picked yourself is untouched.
- Toggles are the accent colour throughout: solid when on, the same
  colour at low alpha when off, instead of Material's grey-for-off.
  Slider tracks lost their grey inactive half the same way.
- Media-tile progress bars, the loading bar over an opening source,
  the video position slider, the transcript's selected line, the
  volume and brightness sliders and the subtitle picker's folder
  icons all follow the accent instead of a hardcoded red. Red is kept
  where it carries meaning: destructive actions (delete, clear),
  warnings, the recording indicator, and the toggled-on markers that
  need to stand out *against* yellow.
- Long-pressing the **cog** in the ッツ source bar opens the 白い熊
  辞書 UI page — the same gesture the home page's ⋮ already carried,
  so appearance settings are reachable without leaving the Reader.
- The dictionary settings dialog and the 白い熊 辞書 UI page are both
  **packed tight and set larger** — bigger labels, no inter-line
  padding, switches and radios stripped of their 48px tap-target
  padding, sliders capped so rows sit directly under each other.
- The two font-size fields left the dictionary settings dialog; all
  dictionary typography now lives in one place, on the UI page. The
  dialog carries a **"Fonts and sizes — 白い熊 辞書 UI"** row that opens
  that page scrolled straight to its Dictionary section.
- Dictionary defaults are now **24** for entries and **28** for
  headings (were 16 and 22). Installs still sitting on the old
  defaults are moved up once; a size you set yourself is left alone.

### Fixed

- **The Reader tab no longer waits on the ッツ library.** Opening it
  boots the whole ッツ web app in a hidden webview and has it
  enumerate IndexedDB — 57 MB of assets served by a Dart HTTP server
  on the same isolate that draws the spinner — and until it answered,
  the tab showed nothing. It now paints the last known library
  immediately from a cache and swaps in the fresh listing when the
  scan lands. The same applies to the All books shelf.
- **A stalled scan can no longer hang the tab forever.** The scan
  waited with `while (items == null)` and no timeout, so a single
  dropped request left the spinner turning until the app was killed.
  Every step now has a 25-second deadline, falls back to the cached
  listing, and drops the wedged webview so the next attempt starts
  clean.
- Book covers are written to disk once and skipped on later scans
  (they were re-encoded as base64 blobs on every single scan), and
  one webview per language is now shared by scans and deletes and
  disposed after two minutes idle, instead of one cold-loaded webview
  per operation.
- **Startup could hang on a black screen.** Every cold start
  requested the camera permission — which nothing in the app uses —
  and waited for the system dialog. Dismissed rather than answered,
  that dialog leaves the request unresolved, and it runs before the
  database opens, so the app sat at 0% CPU showing nothing. The
  camera request is gone and the remaining permission requests carry
  a 45-second deadline: missing it costs the permission, not the
  launch.
- Importing an EPUB from the Reader tab could attach the imported
  book as its own **translation book**, opening the split view with
  the same book on both sides. The translation pane adopts whatever
  book it lands on — correct when picking a translation through its
  manager, wrong when an import was routed there. The Reader tab's
  import button now always targets the primary pane (forcing it onto
  the library manager if needed), a book can no longer be registered
  as a translation of itself, and any such association already saved
  is dropped when the book is next opened.

## [1.5.0+6] - 2026-07-25

### Added

- 白い熊 辞書 UI settings page (sister-repo pattern): first item in the
  home menu, and long-press on the menu (⋮) icon opens it directly.
  kxkb-style layout — bold word-width-underlined headings, thin section
  spacers, deep indents, tight rows. Settable live (the running app is
  the preview): background/text/icon/border/accent colours (RGBA-slider
  picker with 8 prior-colour boxes and live hex preview), font — with
  external .ttf/.otf import and each font rendered in its own glyphs —
  weight, global text scale, and dialog/button border width and corner
  radius (sliders, down to 0). Black/yellow is the initialized default.
- Export/Import on the UI page (Kōjiki flow): settable export
  directory (red until set) with latest-export status queried on open;
  category checkboxes incl. generated artifacts (scanned-PDF OCR
  volumes · subtitle-OCR bitmaps · imported fonts, on by default) and
  the cross-device data bundle (off by default); Arcanechat pill row
  (Cancel left, Import · Export right); export success dialog closes
  the whole chain, import offers Later / Restart now.
- 保存復元 automation contract (自由作業盤): token-gated
  `shiroikuma.jisho.action.EXPORT_STATE` / `LIST_CATEGORIES` broadcast
  receivers run the export headlessly (foreground service + background
  Flutter engine) with real-count progress broadcasts and a
  path|bytes|size|categories reply. Automation switch (default off)
  and tap-to-copy token live in the Export/Import section.

### Changed

- Exports always produce ONE zip: `shiroikuma-jisho_<datetime>.zip`
  (no version in the name); a ticked cross-device bundle embeds inside
  it as `app_data.zip` instead of writing a second file. Old export
  names remain importable. The standalone cross-device menu items
  moved from the home menu into the Export/Import panel.
- Checkboxes app-wide: yellow outlined square with yellow checkmark,
  never a filled block.

## [1.5.0] - 2026-07-25

### Added

- Scanned-PDF viewer redesign in the app's black/yellow: black page
  surround, yellow page edge, black toolbar with yellow controls — 50%
  larger by default and adjustable (100–200%) from the mokuro/PDF settings
  dialog. Pages render inverted by default (pure `#FFFF00` ink on black via
  an exact color-matrix filter), toggleable with a ◐ button in the toolbar.
- Tapping scanned text now pops the recognised OCR line out BESIDE the ink
  (left of the column for vertical text, below for horizontal) with the
  tapped character aligned to the finger, and looks it up immediately —
  compare the OCR against the scan at any zoom. Volumes imported from this
  version carry exact per-line geometry; older volumes should be reimported.
- Long-press a revealed OCR line to edit it in place and fix recognition
  errors; corrections are searched immediately and persisted into the
  volume on disk.
- PDF import now runs under a foreground service with a progress
  notification, so it keeps running when the app is backgrounded or the
  screen is off.

### Changed

- Full toolchain migration: Flutter 3.13.5 → 3.44.x, Gradle 7.2 → 9.1.0,
  AGP 7.1.2 → 9.0.1, JDK 11 → 21, compileSdk 34 → 36, and the entire
  dependency graph moved to maintained packages (isar → isar_community,
  flutter_ffmpeg → ffmpeg-kit, upstream flutter_vlc_player 7.4.4 and
  flutter_inappwebview 6.1.5 replacing 2023-era forks, ML Kit un-vendored).
  Mostly invisible by design (Material 3 deliberately opted out to keep the
  e-ink look; targetSdk stays 32), with two user-visible effects:
  - Dictionary search bloom filters now actually persist: the optimisation
    existed but silently never activated because code generation was frozen
    on the old toolchain. Newly imported dictionaries get faster negative
    lookups; existing dictionaries behave as before until reimported.
  - Player upgraded to libVLC 3.6.3.

### Fixed

- PGS subtitles stay visible when pausing mid-cue: the paused-frame bitmap
  overlay (from the OCR bitmap store) now redraws on any pause, not only at
  auto-pause cue boundaries — the new libVLC clears its own subtitle surface
  on every pause, which used to leave the frozen frame bare.

## [1.4.0+25] - 2026-07-24

### Added

- "OCR image subtitles" action in the player's audio/subtitles menu (next to
  "Load subtitles"): converts a Blu-ray PGS subtitle track to real text via
  on-device OCR. Image tracks are detected with ffprobe
  (`hdmv_pgs_subtitle` / `dvd_subtitle`); the chosen track is demuxed with a
  stream copy, decoded by a pure-Dart PGS `.sup` parser (palette/RLE, small
  renders upscaled 2x), each event recognised with the ML Kit Japanese
  engine, and the result written as a `<video-basename>.ocr.srt` sidecar
  next to the video (falling back to the app's `ocrSubtitles/` directory if
  the video's folder is not writable — both locations auto-load on every
  later open). The progress dialog shows ffmpeg extraction percentage, then
  per-event OCR counts; the generated track then behaves like any text
  subtitle: display, tap-to-lookup, and Anki export. VobSub (DVD) tracks
  are detected and listed as not yet supported: a `.idx`/`.sub` SPU parser
  is in the tree, but ffmpeg has no VobSub muxer to extract with — the
  extraction route is future work.
- The player now shows a small top-center status pill while ffmpeg scans a
  newly opened video for embedded subtitles ("Scanning embedded
  subtitles... N%"), so multi-minute passes over large files no longer look
  like a hang. Text-only by design — no spinner — to stay calm on e-ink.
- When OCR'd subtitles are active, the player also renders the original
  bitmap track natively (via VLC's own SPU renderer, enabled only in this
  mode) under the OCR'd tappable text — recognition errors are visible by
  direct comparison. Selecting any other subtitle turns the bitmap overlay
  back off. OCR'd cues end 50 ms before the bitmap's own clear time so
  pause-on-subtitle-end stops while the bitmap is still on screen
  (regenerate an existing `.ocr.srt` via the "OCR image subtitles" menu
  action to pick up the new timing). Image tracks are excluded from the
  per-open embedded-extraction scan — their bitmaps are only unpacked when
  OCR or the comparison overlay needs them, saving a full-file ffmpeg pass
  per image track on every open.
- Bottom-sheet menus restyled: rows are yellow (dark theme) with the active
  option in red plus a trailing red check mark. Previously every row's icon
  was red, drowning the red active highlight.
- In pause-on-subtitle mode with the bitmap comparison overlay active, the
  cue plays to its natural end (speech uncut) and the playhead stays put:
  the just-ended cue's original bitmap is drawn back over the paused frame
  by the app itself, from a per-event bitmap store (PNG per subtitle event
  plus timing index) saved during the OCR pass. No seeking, no playback
  nudging — resume simply continues, replaying nothing. During playback
  VLC still renders the live bitmap track natively. OCR runs from before
  this build have no bitmap store; re-run OCR on the track to create it.
- Local videos now open paused at the persisted resume position, with that
  position's frame displayed: playback is held as soon as VLC reports the
  resume seek applied (position past zero) and a frame decoded. The
  persisted subtitle track loads and is selected while paused; playback
  starts on the user's play press — the first cue no longer renders with
  the wrong (first) track.
- The primary subtitle track selected during playback is now persisted per
  video (like the secondary track always was) and restored on reopen —
  including the OCR'd track, which brings the bitmap comparison overlay
  back with it. "None" is remembered too. Persistence is by stable track
  key, not list position.
- Each image track now gets its own OCR sidecar (`<basename>.ocr-sN-lang
  .srt`), so videos with several PGS tracks (e.g. eng+cze+jpn) track their
  OCR state independently — "✓ OCRed" and the active mark apply per track,
  not globally. Sidecars named with the old `.ocr.srt` scheme keep loading
  as plain external subtitles; re-run OCR to adopt per-track naming.
- Bottom-sheet menus (e.g. "Select subtitle") carry a yellow rounded
  border in the dark theme, matching the dialogs.
- Dialogs ("Exit Media" and all other alert dialogs) restyled in the dark
  theme: yellow rounded border on the panel, and dialog buttons rendered as
  yellow-bordered pills.
- The player status pill now covers the whole loading sequence: it appears
  as "Loading video..." over the black window from the moment the player
  page opens (this phase grows with file size), switches to the ffmpeg
  scanning/extraction percentages, and clears when subtitles are ready.
  Styled yellow-on-black with a yellow rounded border, as is the OCR
  completion flash.
- The "Select subtitle" sheet now integrates the image-subtitle OCR flow:
  a PGS/VobSub track's line reads "(run OCR to use)" and tapping it starts
  the OCR pass directly; once the `.ocr.srt` exists the same line shows a
  green "✓ OCRed" tick and selecting it displays the OCR'd subtitles. The
  dead extraction entries image tracks used to produce, and the redundant
  raw "[.ocr.srt]" external line, no longer appear.

- "Scanned PDF" Reader media source: import an image-only PDF and study it
  as a mokuro-style volume — each page is rasterised on-device (native
  Android `PdfRenderer` over the new `shiroikuma.jisho/pdf` MethodChannel,
  JPEG pages capped at 2000 px wide), OCR'd with the ML Kit Japanese engine,
  and emitted as a legacy-mokuro HTML file that opens in the existing mokuro
  browse page with full tap-to-lookup, sentence mining, and page-image card
  creation. Import shows a "Page X/N" progress dialog; generated volumes
  live under the app documents `scannedPdf/` directory and appear in the
  source's own history. Viewer settings (volume-key paging, dark theme,
  highlight-on-tap, etc.) are shared with the Mokuro source. The mokuro
  0.2.5 legacy HTML runtime (GPL-3, kha-white/mokuro) is vendored under
  `assets/mokuro-template/`.

- On-device Japanese OCR engine (Google ML Kit text recognition v2, bundled
  Japanese model — works offline, ~4 MB APK growth) as the groundwork for
  studying image-based (non-SRT) subtitles such as Blu-ray PGS tracks. The
  `google_mlkit_text_recognition` 0.16.0 / `google_mlkit_commons` 0.12.0
  plugins are vendored under `vendor/` with their SDK/AGP constraints relaxed
  to build on this project's pinned toolchain. A temporary "OCR test (image)"
  entry in the home settings menu picks an image file and shows the raw
  recognition result; it will be replaced by the real subtitle-OCR flow.

## [1.4.0+6] - 2026-07-22

### Fixed

- The player no longer auto-selects a non-functional "Subtitle - Default" entry on videos with more than one embedded subtitle track in the target language (e.g. jiyudoga study mkvs with `aligned` + `asr`). The language-targeted ffmpeg extraction fails on such files after creating a zero-length output, and that empty file used to be treated as a working subtitle; it is now validated and discarded, so the first real embedded track (`aligned`, the Matroska default) is auto-selected and the dead "Default" entry no longer appears.
- Startup and player backgrounds are now pure black with the OS in light mode too: the day-variant Android `LaunchTheme`/`NormalTheme` were based on `Theme.Light` (white window behind the Flutter UI and the video surface) and the Android 12+ day splash was white; all are now black, as is the blank cold-start root behind externally-launched media.

### Changed

- Dark-theme panel surfaces (modal bottom sheets such as the player's track menu, dialogs, popup menus, cards) are now pure black `#000000` instead of dark grey, matching the black/yellow theme and e-ink rendering.

### Notes

- The jiyudoga study-export contract changed (jiyudoga 0.25.1+20): each export is now a single `.mkv` with the study subtitles embedded as Matroska `S_TEXT/UTF8` (SubRip) tracks (`aligned` as default, `asr` alongside when both exist), instead of an mp4 plus `.srt`/`.asr.srt` sidecars. The "YouTube offline" source handles both shapes — the listing scans `.mkv`, embedded tracks are extracted by the player's existing ffmpeg path, and legacy mp4+sidecar exports keep working. Exports made with the short-lived 0.25.1+19 WEBVTT flavour render no text anywhere and should simply be re-exported; the app does not special-case them.

## [1.4.0+3] - 2026-07-22

### Added

- "YouTube offline" Player media source for study videos exported by shiroikuma-jiyudoga's "Study in jisho" button. Listed in the Player source picker between Local Media and YouTube; shows the persisted study folder's videos newest-first with resume positions and thumbnails, hiding entries whose file was deleted. Playback, same-basename SRT sidecar detection (aligned `.srt` defaulting over `.asr.srt`) and thumbnails reuse the Local Media pipeline.
- New Android intent `shiroikuma.jisho.intent.action.STUDY_VIDEO` (extras: `path`, `subtitlePath`, `studyDir`, `title`, `videoId`, `source`): persists the study folder, imports the video into the "YouTube offline" source and opens the player immediately. Works on both cold start and warm delivery; also fireable from adb for testing. The contract is shared with jiyudoga — changes must land in both repos together.

### Changed

- App launcher label changed from `白い熊の辞書` to `白い熊 辞書` (Android and iOS).

## [1.4.0+2] - 2026-07-16

### Fixed

- The Reader tab no longer gets stuck in a "Local server port already in use / Retrying in 3 seconds…" loop after exiting and re-opening the app. When the Android process outlives the UI (audio service, dictionary indexing in progress), the old run's TTU asset server still held its fixed port and the relaunched app could never bind it. The server now binds with `shared: true` (`SO_REUSEPORT`), so a relaunch binds alongside any stale holder instead of retrying forever.

### Changed

- The Android `versionName` now carries the full pubspec version verbatim — `X.Y.Z+N` on dev builds, bare `X.Y.Z` on releases — so installers and the in-app version line can tell dev builds apart. Previously Flutter stripped the `+N` and every dev build presented itself as the same `X.Y.Z`.
- Built APKs are named with the `shiroikuma-jisho_` prefix (previously `shiroikumanojisho_`), aligning with the other shiroikuma-* apps.

## [1.4.0] - 2026-06-13

### Added

- Toggle for the left-edge font-size swipe gesture in dictionary results, in the dictionary settings dialog ("Left-edge font-size swipe gesture"). Lets the gesture added in 1.0.4 be turned off on devices where it interferes with scrolling or is triggered accidentally. Persisted under the `dictionary_font_size_swipe_enabled` preference; defaults to on, preserving existing behaviour.

### Fixed

- The card-creator buttons on a dictionary lookup no longer crash when a result references a dictionary that has since been deleted. Entries with a dangling dictionary reference are now skipped instead of dereferenced, and a lookup that yields no usable meanings leaves the field empty rather than throwing.
- Frequency information in dictionary results no longer renders a grey screen. Two causes were fixed: a Yomichan definition whose CSS omits `list-style-type` now falls back to the `square` list style instead of throwing, and frequencies referencing a deleted dictionary are skipped.
- The app no longer requests the `READ_PHONE_STATE` permission. It was pulled in transitively by a dependency and tripped Google Play Protect on install; it is now stripped at manifest-merge time with `tools:node="remove"`.

## [1.3.1] - 2026-05-20

UI-fit fixes for narrow screens.

### Added

- Customisable reader audio toolbar: per-button visibility setting persisted under the `reader_audio_toolbar_hidden_items` preference. Eight buttons are hideable (seek previous/next, replay, time display, previous/next chapter, translation-book toggle, navigate menu); play/pause, the position slider, and the options menu are always shown.
- "Customise reader toolbar" entry in the home settings menu, alongside "Reader audio toolbar height". The same dialog is also reachable from the toolbar's own options (⋮) menu — having both is deliberate, since the toolbar entry point itself can be clipped off-screen on narrow devices, making it unreachable.

### Fixed

- Long labels in the home settings menu ("Reader audio toolbar height", "Import data (cross-device)", "View repository on GitHub") clipping off the right edge of the screen instead of wrapping. Each menu item's text is now `Flexible` with `softWrap: true`.

## [1.3.0] - 2026-05-12

### Added

- Seven Android broadcast intents for external control of the reader audio toolbar, in the `shiroikuma.jisho.action.PLAYBACK_*` namespace:
  - `PLAYBACK_NEXT_SUBTITLE`, `PLAYBACK_PREVIOUS_SUBTITLE`, `PLAYBACK_REPLAY_SUBTITLE` — subtitle navigation.
  - `PLAYBACK_TOGGLE_PLAY_PAUSE` — toggle play/pause.
  - `PLAYBACK_PREVIOUS_CHAPTER`, `PLAYBACK_NEXT_CHAPTER` — chapter navigation.
  - `PLAYBACK_CYCLE_MODE` — cycle normal → condensed → auto-pause → normal, used to switch in and out of shadowing mode without opening the toolbar menu.
- Tasker (and any other broadcast-capable automation tool) can drive these via Send Intent: action set to one of the strings above, package set to `shiroikuma.jisho`, target set to Broadcast Receiver, no extras required.

### Notes

- Intents only take effect when the app is running and a reader page with audio is open. Intents fired against a closed app or a non-reader page are silently dropped; the app deliberately does not cold-start playback from a broadcast.

## [1.2.0] - 2026-05-06

Major release: full cross-device data portability.

### Added

- Cross-device export and import as a complement to the existing on-device backup and restore. Where backup and restore produce bit-for-bit snapshots only meaningful on the same device, export and import serialise everything as portable JSONL plus a manifest so a bundle can move between devices and survive package re-signing.
- The bundle covers all Isar collections (dictionaries, dictionary entries, tags, frequencies, pitches, anki mappings, media items, search history, browser bookmarks, mokuro catalogs), every Hive preferences box (`appModel`, `readerAudio`, per-source boxes), the `dictionaryResources/` directory, and per-language TTU IndexedDB contents.
- Bundles are ZIP files written to `/storage/emulated/0/tmp/`. On import the chosen bundle is extracted, live data is replaced, and the app exits to force a clean reload.
- Audio path remap on import: when imported audio paths do not resolve on the destination device, the user can supply a new base directory and a suffix matcher rebinds files automatically without a full re-import.

### Fixed

- **TTU language lookup on import was silently skipping every language.** The code looked up `appModel.languages[code]` where `code` was bare (`"ja"`) but the map was keyed on locale tags (`"ja-JP"`). Books were never restored. Now matches by `languageCode` directly.
- **Theme reverted from dark to light after import.** The `is_dark_mode` Hive key was missing from bundles whenever the user had not explicitly toggled the theme, and a Flutter cold-start `platformBrightness` quirk would then return Light briefly and lock in the wrong theme. Exports now force-persist the effective value to the bundle.
- Hive boxes are explicitly flushed and `Hive.close()` is called before `exit(0)` on the import side, so the OS does not lose pending writes during the post-import restart.
- Backup and restore inherited matching improvements: progress dialog, async cleanup, and tolerance for files vanishing mid-snapshot (Chromium IndexedDB blob garbage collection used to race against the copy and fail the whole backup with `PathNotFoundException`).

### Changed

- Isar import uses `writeTxnSync` + `putAllSync` for bulk writes. Significantly faster than the async pair on Android flash, with batch sizes small enough to keep the UI responsive.
- Staging and extract directory cleanup is asynchronous with progress reporting; the previous synchronous `deleteSync` blocked the UI thread for tens of seconds on slow flash (Boox-class e-readers).

## [1.1.0] - 2026-05-04

Baseline minor release. No functional changes from 1.0.4 — version bump only, establishing a clean `1.1.0` baseline before the export/import work that would land in 1.2.0.

## [1.0.4] - 2026-04-24

### Added

- Dictionary font-size adjustment via swipe along the left edge of the entry view, with a real-time overlay showing the current size. Existing centred overlays unified so all dictionary HUDs share the same anchor.

## [1.0.3] - 2026-04-24

### Added

- Per-book, per-pane font size in the TTU reader, replacing the previous shared-origin behaviour where every book inherited the same font size.

### Fixed

- TTU writing mode now forced per-WebView to match each book's body CSS, fixing books that displayed in the wrong orientation when reopened.
- Appearance CSS no longer applied on TTU non-book pages (library, settings), where it caused visual glitches.

### Changed

- Home title bar decodes the pubspec `+N` build counter directly from the packed `versionCode` so dev builds are unambiguously identifiable.

## [1.0.2] - 2026-04-24

### Added

- Every Japanese word in a dictionary entry is tappable for recursive lookup. Previously only the headword was tappable.
- Scan-words behaviour (auto-detection of word boundaries on tap) extended to all supported languages, not just Japanese.
- Back and Close-all buttons on the recursive entry AppBar so deep dictionary chains can be exited cleanly.

### Fixed

- Per-book reader state collision across languages: opening a book in one language no longer clobbered the saved position of a same-titled book in another.

## [1.0.1] - 2026-04-24

### Added

- Per-book writing mode in the TTU reader, with Japanese books defaulting to vertical writing.
- Primary/Secondary font override that takes precedence over TTU's default font rules.
- `tools/bump-build.sh` helper for advancing the pubspec `+N` counter on dev builds.

### Changed

- Dictionary search UI replaced the heavy FloatingSearchBar with a simple AppBar plus a search dialog; faster to open, easier to dismiss.
- Per-book reader state is keyed by the TTU SPA book id rather than the surrounding widget item, so state survives navigation churn within TTU.
- TTU paragraph spacing uses logical `margin-block-end` so vertical-writing books fill their columns correctly without horizontal gap artifacts.
- Audio toolbar's filename overlay is smaller and indicates `/srt` (subtitle file presence) in the title; dev builds also show the `+N` build counter in the title.

## [1.0.0] - 2026-04-23

Initial release after the rename and restructure from `ShiroiKuma0/jidoujisho2`.

### Changed

- The repo was flattened: the Flutter project root is now the repo root, no more `yuuna/` subdirectory.
- Dart package renamed `yuuna` → `shiroikumanojisho`.
- Android `applicationId` and Java package renamed to `shiroikuma.jisho`.
- App display name set to `白い熊の辞書` (Android and iOS); iOS identity also updated.
- Version baseline reset to `1.0.0+1` post-rename.

[Unreleased]: https://github.com/ShiroiKuma0/shiroikumanojisho/compare/1.4.0+25...HEAD
[1.4.0+25]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.4.0+25
[1.4.0+6]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.4.0+6
[1.4.0+3]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.4.0+3
[1.4.0+2]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.4.0+2
[1.4.0]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.4.0
[1.3.1]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.3.1
[1.3.0]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.3.0
[1.2.0]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.2.0
[1.1.0]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.1.0
[1.0.4]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.0.4
[1.0.3]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.0.3
[1.0.2]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.0.2
[1.0.1]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.0.1
[1.0.0]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/1.0.0

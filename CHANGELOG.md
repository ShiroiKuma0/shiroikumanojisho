# Changelog

All notable user-visible changes to **白い熊の辞書 (shiroikumanojisho)** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_Nothing yet._

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

[Unreleased]: https://github.com/ShiroiKuma0/shiroikumanojisho/compare/1.4.0+3...HEAD
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

# Fork audit: filesystem_picker, receive_intent, material_floating_search_bar

Audit date: 2026-07-24. Clones under `scratchpad/forks/` (fsp, ri, mfsb, mfsb2).
App under audit: `/home/shiroikuma/git/shiroikuma-jisho` (pins in `pubspec.yaml` lines 37–41, 92–95, 110–113).

Patch verdict legend: (a) obsolete in the migration target, (b) behavior customization to preserve, (c) unclear.

---

## Fork 1: filesystem_picker

- Fork: `arianneorpilla/filesystem_picker`, branch `jidoujisho`, package at `package/`.
- Upstream: `andyduke/filesystem_picker`, master = 4.1.0 (the migration target).
- Merge-base with upstream master: `753a506` = upstream **2.0.0-nullsafety.0**. That is the base version.
- Fork-only commits: ~35, but the fork is not a patch series on upstream — it inherited a **wholesale internal rewrite** from two intermediate forks (kuchienkz, alr2413: multi-root, multi-select, restructured `lib/src`), then jidoujisho-era commits on top. Upstream 2.x files (`picker_page.dart`, `filesystem_list.dart`, `breadcrumbs.dart`, `common.dart`) were deleted/replaced by `file_system_picker.dart` + `widgets/` + `utils/`. Cumulative diff vs base: 33 files, +2255/−979.
- No android module in `package/` (pure Dart) — **no namespace concern**. (`MANAGE_EXTERNAL_STORAGE` bits live only in the example app.)
- Extra deps added by fork: `marquee ^2.2.3` (wrapped by vendored `widgets/marquee.dart`), `pedantic` (discontinued, dev-lint only).

### Patch list and verdicts

Inherited rewrite (pre-jidoujisho, kuchienkz/alr2413 lineage):
- Multi-root support: `open(rootDirectories: List<Directory>, rootNames:)`, storage drawer → **(b/partially a)**. Upstream 4.0 added `shortcuts: List<FilesystemPickerShortcut>` which covers multi-root browsing, but with a different API and UI (sidebar/shortcut list, not the fork's root list).
- Multi-select + `Iterable<String>` return, bottom confirm bar → **(b/c)**. Upstream is single-select `Future<String?>`. The app only ever uses `filePaths.first`, so single-select upstream is behaviorally sufficient — but every call site returns `Iterable<String>?` today.
- `cancelText` parameter → **(b, trivial)**. Not in upstream.
- Back button navigates up instead of closing → **(c)**. Upstream 4.x has breadcrumbs + Go Up; unverified whether back-intercept matters on device.

jidoujisho-era commits (`aa13540`…`aedba61`):
- `aa13540` "Personal changes": tap file = immediate pop with result; hide bottom bar for single-select file mode → **(a-ish)**: upstream `FileTileSelectMode.wholeTile` gives tap-to-pick.
- `a04d45d`/`e96d231`/`fc65b3a` theme changes, hardcoded Chisa coloring, `themeData:` param → **(a)**: superseded by upstream 4.x `FilesystemPickerTheme` / `FilesystemPickerAutoSystemTheme` (different API; call sites pass `themeData: Theme.of(context)` today).
- `3827555` Safe area → **(a)** upstream 4.x layouts handle this.
- `968a4b3` null fix, `3276b03` Flutter 3 null safety, `aedba61` Dart 3.0.0 fixes → **(a)**: upstream 4.1.0 SDK is `>=2.17 <4.0.0`, Flutter >=3.0.
- `8f76133` + `2d7e454` marquee scrolling of long filenames (`filename_text.dart`, vendored `marquee.dart`) → **(b)**: no upstream equivalent; upstream truncates. Matters on the narrow Boox Palma.
- `91b72c0`/`e270388` + `2d7e454` `usedFiles:` / `currentActiveFile:` coloring (highlight already-imported files and the currently-open file in the list) → **(b)**: pure jidoujisho feature, no upstream analog (theme cannot style per-file). The app passes these in `player_local_media_source.dart` and `reader_mokuro_source.dart`.
- `f882a0e` per-extension file icons (`file_icon_helper.dart`: video/audio/image/pdf icons) → **(b, minor)**: upstream has one themable `fileIcon` for all files.
- `c0f132e` + `9b8efe1` case-insensitive alphabetical sort → **(b, minor)**: upstream sorts with raw `a.path.compareTo(b.path)` (case-sensitive, dirs first).
- `6c4a39f` light-theme + breadcrumbs fixes → **(a)**: fixes to fork-only code; upstream 4.x breadcrumbs rewritten.

### App call sites (4)

`player_source_page.dart:3804`, `player_local_media_source.dart:146`, `reader_scanned_pdf_source.dart:118`, `reader_mokuro_source.dart:231` — all use `FilesystemPicker.open(rootDirectories:, usedFiles:, currentActiveFile:, themeData:, cancelText:, pickText:, allowedExtensions:, fsType:, folderIconColor:)` returning `Iterable<String>?`. None of `rootDirectories`, `usedFiles`, `currentActiveFile`, `cancelText`, `themeData` exist in upstream 4.1.0.

### Recommendation

**Keep-fork-and-patch.** Upstream 4.1.0 is a different API and drops two real features the app depends on (used/active file highlighting, marquee) plus multi-root in the shape the call sites use. The fork is already Dart-3-clean (tip commit "Dart 3.0.0 fixes"); for the toolchain migration it only needs its `environment.sdk` widened (currently `>=2.12.0 <3.0.0` in pubspec — Dart 3 resolves it via null-safety compat, but Dart 4 will not) and possibly a `pedantic` removal. Migrating to upstream 4.1.0 would mean rewriting 4 call sites AND reimplementing used/active highlighting inside upstream's list widget — a port, not a swap. Nothing here blocks AGP 8: no android module.

---

## Fork 2: receive_intent

- Fork: `arianneorpilla/receive_intent` at pinned commit `3854d07`.
- Upstream: `daadu/receive_intent`; migration target **0.2.7** (`ee3d0da`).
- Merge-base: `5950356` = upstream **v0.2.3**. That is the base version.
- Fork-only commits: exactly **one** (`3854d07` "Custom changes for handling Jellyfin intent"). (Branch `jidoujisho` has one more, `f4e5433` — whitespace only, same title; the app pins `3854d07`.)

### The single patch — verdict (b), preserve

`setResult` gains a required `action` parameter, threaded Dart → MethodChannel → Kotlin, and the result Intent is built as `Intent(action).putExtras(jsonToBundle(json))` instead of upstream's action-less `jsonToIntent(json)`. Upstream 0.2.7 (and even current master) still has no `action` support — **not obsolete**. The app depends on it: `player_source_page.dart:169` and `:1113` call `ReceiveIntent.setResult(kActivityResultOk, action: 'is.xyz.mpv.MPVActivity.result', data: {position, duration})` — the mpv result contract Jellyfin's external-player integration matches on. Without the action, Jellyfin ignores the playback-position result.

The patch is tiny (~15 lines across `lib/receive_intent.dart` + `ReceiveIntentPlugin.kt`) and the touched region is unchanged between 0.2.3 and 0.2.7 (0.2.3→0.2.7 only added ByteArray support in `Utils.kt` and gradle/API-level fixes), so it re-applies cleanly on 0.2.7.

### Namespace / AGP 8 findings

- Fork pin `3854d07`: `android/build.gradle` has **no `namespace`**, `compileSdkVersion 30`, minSdk 16 — **breaks under AGP 8+** (namespace mandatory) and is the reason this fork must move.
- Upstream 0.2.7: declares `namespace 'com.bhikadia.receive_intent'` (guarded by `hasProperty("namespace")`, so it also builds on AGP 7), `compileSdk 34`, Java 8.
- Upstream master (post-0.2.7, unreleased): `compileSdk 35`, Java 17, AGP 9 fixes (`21f20d9`) — a fallback if 0.2.7's gradle still fights the new toolchain.

### Recommendation

**Rebase the fork's single commit onto upstream 0.2.7** (fresh branch on the arianneorpilla fork, or vendor it), then pin that. Do not adopt plain upstream 0.2.7 — the Jellyfin `action` patch would be lost and cannot be emulated from the app side (the channel has no field for it; `data` entries become extras, not the intent action).

---

## Fork 3: material_floating_search_bar

- Fork: `arianneorpilla/material_floating_search_bar`, ref `jidoujisho`.
- Original upstream `bnxm/material_floating_search_bar`: **repo deleted from GitHub** (404; likewise no `bernaferrari` continuation repo exists). The fork has no shared upstream history anyway — it starts with a `c70fae5` "Mirror" commit that snapshots upstream **0.3.7** (pubspec/CHANGELOG in the mirror confirm; 0.3.7 was the last upstream release). Base version: **0.3.7**.
- Continuation `material_floating_search_bar_2` actually lives at **`github.com/AlwinFassbender/material_floating_search_bar`** (per pub.dev repository field). Latest published: **0.5.0** (branches `0.5.0`/`0.5.1` in the repo; `main` sits at 0.4.2).
- No android module in either fork or continuation (pure Dart) — **no namespace concern**.

### Fork-only patches (Mirror → jidoujisho tip `4507505`) and verdicts

Cumulative real diff is only 4 hunks (rest is committed `.dart_tool`/generated noise):
1. `floating_search_bar_scroll_notifier.dart`: pass `devicePixelRatio: metrics.devicePixelRatio` to `FixedScrollMetrics` (Flutter 3.10 requirement) → **(a)**: present verbatim in `_2` 0.5.0 (its 0.5.0 changelog entry is exactly this fix).
2. `util/util.dart`: `WidgetsBinding.instance?.` → `WidgetsBinding.instance.` (Flutter 3 non-null binding) → **(a)**: present in `_2`.
3. `pubspec.yaml` sdk `>=2.12.0 <3.0.0` → `>=2.19.2 <3.0.0` → **(a)**: `_2` 0.5.0 is `>=3.0.0-0 <4.0.0`.
4. `analysis_options.yaml` lint tweak → **(a)**: irrelevant.

No behavior customizations at all — every fork patch is a Flutter/Dart compat shim already shipped in `_2` 0.5.0.

### API compatibility of `_2` 0.5.0

- Import changes from `package:material_floating_search_bar/material_floating_search_bar.dart` to `package:material_floating_search_bar_2/material_floating_search_bar_2.dart`; same export set (FloatingSearchBar, actions, scroll notifier, transitions, CircularButton, SearchToClear).
- Field-level diff of `FloatingSearchBar`: identical except `toolbarOptions` → `contextMenuBuilder` (0.4.2 change). The app never passes `toolbarOptions` to the search bar (its only `ToolbarOptions` use is in its own `jidoujisho_selectable_text.dart`), so this does not bite.
- Symbols the app uses (10 files): `FloatingSearchBar`, `FloatingSearchBarAction` (33 uses), `FloatingSearchBarController`, `FloatingSearchAppBar`, `SearchToClear` — all present unchanged in `_2`.

### Recommendation

**Switch to pub package `material_floating_search_bar_2: ^0.5.0`.** Purely mechanical: swap the git dependency for the pub dep and rename the import in ~10 files. Nothing to preserve from the fork.

---

## Summary table

| Fork | Base version | Fork patches | Verdict | Recommendation | Namespace/AGP8 |
|---|---|---|---|---|---|
| filesystem_picker | 2.0.0-nullsafety.0 | Large rewrite + jidoujisho features (multi-root, usedFiles/activeFile colors, marquee, icons, case-insensitive sort) | Mixed: compat fixes (a), features (b) with no upstream 4.1.0 equivalent | Keep fork; widen SDK constraint for Dart-3+/toolchain; upstream 4.1.0 = full port, not a swap | No android module — n/a |
| receive_intent | 0.2.3 | 1 commit: `setResult` `action` param (Jellyfin/mpv result contract) | (b) preserve — absent even from upstream master | Rebase the one patch onto upstream 0.2.7 and pin that | Fork pin: NO namespace, compileSdk 30 (AGP 8 blocker). Upstream 0.2.7: namespace declared, compileSdk 34 |
| material_floating_search_bar | 0.3.7 (mirror; bnxm repo deleted) | 3 Flutter-3/Dart-3 compat shims | All (a) — all present in `_2` 0.5.0 | Switch to `material_floating_search_bar_2 ^0.5.0` (repo: AlwinFassbender/material_floating_search_bar); rename imports in ~10 files | No android module — n/a |

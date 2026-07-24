# Toolchain migration plan — Flutter 3.13 → 3.44, AGP 7 → 9

Prepared 2026-07-24 from `TOOLCHAIN_MIGRATION_HANDOFF.md` (research July 2026, not
re-verified here except where noted "repo-verified"). This is the working plan for
modernising the entire build toolchain and dependency graph of shiroikumanojisho.
Implementation proceeds phase by phase with device verification between phases, the
same cadence as the OCR project.

## 1. Goals and non-goals

### Goals

- Move the app to current stable Flutter (3.44.x / Dart 3.12) and the current Android
  toolchain (Gradle 9.1.0, AGP 9.0.1, JDK 17, compileSdk 36).
- Replace every dead or unhostable dependency (flutter_ffmpeg, isar/isar_generator,
  wakelock fork, ancient forks) with maintained equivalents.
- Fold the vendored ML Kit packages (`vendor/google_mlkit_text_recognition`,
  `vendor/google_mlkit_commons`) back to hosted pub dependencies.
- Preserve, bit-for-bit where it matters, all frozen external contracts: Tasker
  `shiroikuma.jisho.action.PLAYBACK_*` intents, the 1.2.0+ export/import bundle format,
  jiyudoga single-mkv study-export handling, on-device Isar/Hive data, TTU IndexedDB
  content inside the webview.
- Keep `main` releasable throughout; the migration lives on a branch until the full
  verification matrix is green.
- Update all toolchain documentation (CLAUDE.md, build-and-release skill, README) so the
  JDK-11 pin and related rules invert correctly to their JDK-17 successors.

### Non-goals (each a separate later project, explicitly out of scope)

- **Material 3 adoption.** We opt out (`useMaterial3: false`) to preserve the
  black/yellow e-ink look. Restyling is its own project.
- **targetSdk raise.** Stays 32 through the migration (decision below). The bundle of
  work it triggers (audio_service manifest, granular media permissions, predictive back,
  edge-to-edge, 16 KB page-size compliance) is a follow-up project.
- **Feature work of any kind**, including upstream jidoujisho sync.
- **Slimming the ffmpeg variant.** We port behavior-preserving first (decision below);
  a smaller variant is a later optimisation.
- **hive → hive_ce.** hive 2.2.3 stays unless it fails to build; hive_ce is the
  named fallback only.

## 2. Target-version table

| Item | From (repo-verified) | To |
|---|---|---|
| Flutter | 3.13.5 (Dart 3.1), machine SDK `~/git/flutter` | **3.44.x** (Dart 3.12), second SDK checkout (see Phase 0) |
| pubspec `environment.sdk` | `>=3.0.0<4.0.0` | `>=3.12.0 <4.0.0` |
| Gradle wrapper | 7.2 | **9.1.0** (3.44 template) |
| AGP | 7.1.2 | **9.0.1** |
| Kotlin | KGP 1.8.22 | AGP 9 built-in Kotlin per template (KGP 2.3.20 only if needed; `android.builtInKotlin=false` is a temporary escape hatch, not a destination) |
| JDK | Zulu 11 (`/usr/lib/jvm/zulu11`) | **JDK 17+** (Zulu 17; hard floor — the tooling errors below 17) |
| Gradle integration | imperative `apply from: flutter.gradle` | declarative plugins DSL (mandatory since Flutter 3.29) |
| compileSdk / targetSdk / minSdk | 34 / 32 / 24 | **36 / 32 / 24** (targetSdk deliberately unchanged) |
| NDK | 21.4.7075529 (explicit pin) | no pin — inherit `flutter.ndkVersion` (28.2.x) |
| Java source/target compat | 1.8 | 17 (`jvmTarget` likewise) |
| ML Kit | vendored 0.16.0 under `vendor/` | hosted `google_mlkit_text_recognition ^0.16.0` |

### Dependency targets (from the July 2026 audit)

| Package | From (repo-verified) | To | Class |
|---|---|---|---|
| flutter_ffmpeg | 0.4.2, native variant `full-gpl-lts` (ext in `android/build.gradle`) | `ffmpeg_kit_flutter_new` 4.5.x, variant **full_gpl** (decision 4) | Critical — API reshape, 15 call sites / 5 files |
| isar / isar_flutter_libs / isar_generator | 3.1.0+1 | `isar_community` / `isar_community_flutter_libs` / `isar_community_generator` 3.3.x | Critical — unblocks codegen; same on-disk format (MUST verify on a DB copy) |
| flutter_vlc_player | arianneorpilla fork (git) | upstream **7.4.4** (decision 5, gated on fork diff) | Major |
| flutter_inappwebview | arianneorpilla fork, 2023 commit | upstream **6.1.x** (decision 5) | Major — biggest hand-edit, 54 hits / 8 files |
| wakelock (fork) | diegotori fork (git) | `wakelock_plus` (+ drop `wakelock_windows` override) | Major (mechanically simple) |
| flutter_html / flutter_html_table | 3.0.0-beta.2 | 3.0.0 final | Major (watch-list) |
| share_plus | ^4.0.10 | 13 (`SharePlus.instance.share(ShareParams(...))`) | Major |
| audio_service | ^0.18.9 | 0.18.19 (manifest work deferred with targetSdk) | Mechanical |
| just_audio | ^0.9.31 | 0.10 (check `ConcatenatingAudioSource` usage) | Mechanical |
| audio_session | ^0.1.13 | 0.2.x | Mechanical |
| slang / slang_flutter | ^3.13.0 | 4.x (config migration + regen `strings.g.dart`) | Mechanical |
| intl | ^0.18.0 | 0.20+ | Mechanical |
| file_picker | ^5.3.0 | 11 | Mechanical |
| permission_handler | ^10.2.0 | 12 (needs compileSdk 35+; granular-permission behavior retest deferred with targetSdk) | Mechanical |
| package_info_plus | ^4.0.2 | 10 | Mechanical |
| device_info_plus | ^8.1.0 | 13 | Mechanical |
| flutter_charset_detector | ^1.0.2 | 6 | Mechanical |
| screen_brightness | ^1.0.1 | 2 | Mechanical |
| external_path | ^1.0.1 | 2 | Mechanical |
| flutter_archive | ^5.0.0 | 6 | Mechanical |
| flutter_image_compress | ^1.1.3 | 2 | Mechanical |
| youtube_explode_dart | ^2.5.3 | 3.x (mandatory in practice — old versions rot against live YouTube) | Mechanical |
| google_fonts | ^4.0.4 | 8 | Mechanical |
| carousel_slider | ^4.2.1 | 5 | Mechanical |
| infinite_scroll_pagination | ^3.1.0 | 4 | Mechanical |
| build_runner / json_serializable / copy_with_extension / dart_mappable | current pins | latest + full regen | Mechanical |
| flutter_launcher_icons / flutter_native_splash / restart_app / flutter_exit_app / flutter_logs | current pins | current | Mechanical |
| material_floating_search_bar (fork) | arianneorpilla fork (git) | `material_floating_search_bar_2` (upstream discontinued) | Fork handling |
| filesystem_picker (fork) | arianneorpilla fork (git) | try upstream 4.1.0 (gated on fork diff) | Fork handling |
| receive_intent (fork) | arianneorpilla fork (git) | try upstream 0.2.7, else namespace shim | Fork handling |
| mecab_dart | ^0.1.3 (old FFI plugin) | keep + namespace shim, or vendor if shim insufficient | Fork handling |
| nowplaying (fork) | arianneorpilla fork (git) | keep fork + namespace | Fork handling |
| subtitle (fork) | arianneorpilla fork (git) | keep (pure Dart) | Fork handling |
| spaces / ruby_text / ve_dart / blurrycontainer / marquee / expandable / reorderables / scrollable_positioned_list / clipboard / progress_indicators / multi_value_listenable_builder | various | keep; fix compile errors as they surface | Fork handling |
| hive / hive_flutter | 2.2.3 / 1.1.0 | keep (hive_ce is fallback only) | Frozen |
| local_assets_server | ^2.0.2+12 | keep | Frozen |
| google_mlkit_text_recognition | vendored path dep 0.16.0 | hosted ^0.16.0; delete `vendor/` | Un-vendor |

`dependency_overrides` after the upgrade: drop `collection`, `ffi`, `http`, `logging`,
`wakelock_windows` (gone with wakelock_plus). `freezed_annotation` / `gap` droppable once
the `spaces` fork is patched or replaced. `record_mp3_plus`: retest, then drop.

## 3. Open decisions — resolutions

1. **Single jump to 3.44 (chosen) vs two plateaus.** Single jump. A 3.29/AGP 8.6
   plateau is not shippable anyway (the dependency graph would need intermediate
   versions that we would then immediately redo, since many current package versions
   demand Flutter ≥3.38 — double resolution work for no releasable midpoint). Risk is
   contained instead by sub-phasing inside the branch with per-phase gates.
2. **targetSdk stays 32** through the migration. Fewest runtime behavior changes;
   sideloaded app, no Play pressure. The raise (with audio_service
   `FOREGROUND_SERVICE_MEDIA_PLAYBACK` manifest work, granular media permissions,
   predictive back, edge-to-edge, 16 KB page-size audit) becomes its own follow-up
   project.
3. **Material 3: opt out initially.** `useMaterial3: false` in both ThemeData
   constructions. Preserves the e-ink look; M3 adoption is a separate project.
4. **ffmpeg variant: `full_gpl`.** Repo-verified: the current build already ships
   `full-gpl-lts` (ext `flutterFFmpegPackage` in `android/build.gradle`), so `full_gpl`
   is the behavior-preserving port — no codec/protocol we use today can go missing.
   Phase 0 still audits the actual command strings (subtitle demux/SRT encode, JPEG
   thumbnails, audio extraction) so we know whether a later slim to `https`/`audio` is
   possible, but slimming is decoupled from the migration.
5. **Forks: prefer upstream wherever upstream is alive**, gated per-package on a
   Phase 0 diff of the fork against its base (to enumerate what the fork patched and
   confirm upstream covers or obsoletes it): flutter_vlc_player → upstream 7.4.4,
   flutter_inappwebview → upstream 6.1.x, filesystem_picker → upstream 4.1.0,
   receive_intent → upstream 0.2.7, material_floating_search_bar →
   `material_floating_search_bar_2`. Patch-the-fork only where the diff shows a
   load-bearing patch upstream lacks. Pure-Dart forks (subtitle etc.) stay.

## 4. Branch, rollback, and safety model

- All work on branch `toolchain-migration` off `main`. `main` stays releasable;
  emergency fixes land on `main` and rebase/merge into the branch.
- The flutter_inappwebview hand-edit happens on a sub-branch
  `toolchain-migration-webview` merged back into `toolchain-migration` once the TTU
  reader, mokuro browse, and browser source compile — it is the largest single edit
  (the TTU reader page alone is ~3,600 lines) and deserves an isolated commit series
  that can be reviewed and reverted as a unit.
- Each phase ends in a working-state commit with the phase named in the message;
  rollback to any phase boundary is `git reset`/`revert` on the branch.
- Before merge to `main`: tag the last pre-merge `main` commit
  (`pre-toolchain-migration`) so the old-toolchain state stays addressable forever.
- **Device safety net, taken in Phase 0 before any migration build touches a device:**
  - Full in-app export bundle (contains Isar JSONL, Hive dumps, dictionaries, TTU
    IndexedDB dumps) archived off-device.
  - `adb pull` of `/sdcard/Android/data/shiroikuma.jisho/files/` (raw Isar/Hive).
  - The released `1.4.0+25` APK is already archived in `~/tmp/` and on GitHub.
  - Device rollback path: versionCode is monotonic, so reinstalling the old APK over a
    migration build is a downgrade — the guaranteed path is uninstall → install
    `1.4.0+25` → import the Phase 0 bundle (`adb install -r -d` may work and can be
    tried first, but is not the plan of record).
- **Shared machine SDK:** `~/git/flutter` (3.13.5) is used by other repos
  (shiroikuma-jiyudoga) and is NOT upgraded. The migration uses a second SDK checkout
  (see Phase 0); this repo selects it via `local.properties` `flutter.sdk` plus
  per-session PATH. Other repos keep building unchanged; they migrate on their own
  schedule.

## 5. Phase breakdown

Reality check on buildability: Phases 1–4 are a single non-buildable trench — the old
plugin set cannot build under AGP 9 and the new set cannot build under Flutter 3.13, so
there is no APK between the start of Phase 1 and the end of Phase 4. The gates inside
the trench are therefore non-build gates (pub resolution, Gradle configuration,
analyzer error count trending down). The first APK gate closes Phase 4.

### Phase 0 — Preparation (no repo code changes; ~1 session)

1. Install Zulu JDK 17 alongside Zulu 11; note its path.
2. Second Flutter SDK checkout at `~/git/flutter-3.44` pinned to the current 3.44.x
   stable. `~/git/flutter` untouched.
3. Create branch `toolchain-migration`; record the baseline commit in the first commit
   message.
4. Take the device safety net (bundle export, `adb pull`, verify archive integrity).
5. **ffmpeg command audit:** collect every command string in `subtitle_utils.dart`,
   `player_local_media_source.dart`, `player_media_source.dart`, `subtitle_ocr.dart`,
   `player_source_page.dart`; list codecs/muxers/protocols used; confirm `full_gpl`
   covers all (it must — it is a superset of today's `full-gpl-lts`); note whether a
   slimmer variant would suffice (informational only).
6. **Fork diffs:** for vlc, inappwebview, filesystem_picker, receive_intent,
   material_floating_search_bar, nowplaying — diff each fork ref against its upstream
   base commit and write down what the fork patched. This converts decision 5 from
   "prefer upstream" into per-package confirmed choices.
7. Check `ConcatenatingAudioSource` usage (just_audio 0.10 removed it) and
   `FlutterApplication` subclass absence (v1 embedding removal — expected none).

**Gate:** backups verified restorable-in-principle (bundle opens, manifest sane); fork
diffs written up; ffmpeg audit written up; decisions 4–5 confirmed against the
evidence.
**Rollback:** nothing to roll back — no repo changes.

### Phase 1 — Toolchain skeleton (Gradle files + SDK/env pins; ~1 session)

1. `pubspec.yaml` environment → Dart `>=3.12.0 <4.0.0`, flutter `^3.44.0`.
2. `android/settings.gradle` → declarative form: `pluginManagement {}` reading
   `flutter.sdk` from `local.properties`, `includeBuild(".../flutter_tools/gradle")`,
   plugins block with `dev.flutter.flutter-plugin-loader`, plus
   `com.android.application` and Kotlin plugin versions per the 3.44 template.
3. Root `android/build.gradle`: `buildscript {}` goes away; keep the repository list
   (google, mavenCentral, jitpack, `local-repo`, aliyun mirrors) in the appropriate
   new location (`pluginManagement`/`dependencyResolutionManagement` split per
   template); keep the `flutterFFmpegPackage` ext only until Phase 2 deletes
   flutter_ffmpeg, then remove it; add the **namespace shim** for legacy plugins
   (AGP 8+ requires `namespace` per module):

   ```groovy
   subprojects {
       afterEvaluate { project ->
           if (project.hasProperty('android')) {
               project.android {
                   if (namespace == null) {
                       namespace project.group   // variant: parse plugin AndroidManifest @package
                   }
               }
           }
       }
   }
   ```

4. `android/app/build.gradle` → `plugins { id "com.android.application";
   id "kotlin-android"; id "dev.flutter.flutter-gradle-plugin" }`; add
   `namespace "shiroikuma.jisho"`; compileSdk 36; keep minSdk 24 / targetSdk 32;
   **drop the NDK 21 pin** (inherit `flutter.ndkVersion`); Java/Kotlin targets → 17.
5. **Port the versionCode/versionName logic verbatim** — the pubspec-parsing Groovy
   block (packing `X*1e6 + Y*1e4 + Z*100 + min(N,99)`, versionName = full pubspec
   string) is self-contained and moves as-is. **Known port hazard (repo-verified):**
   the APK-rename + `versionCodeOverride` block uses the legacy variant API
   (`applicationVariants.all`, `com.android.build.OutputFile.ABI`), which AGP 9
   removes — rewrite it onto the `androidComponents`/new Variant API, preserving the
   output-filename scheme and the identical-versionCode-per-ABI behavior.
6. Keep `packagingOptions pickFirst 'lib/**/libc++_shared.so'`, the release
   `minifyEnabled true` + debug-signing config, and the direct Gradle deps (AnkiDroid
   2.17alpha14, RxLogs, `com.google.mlkit:text-recognition-japanese:16.0.1` — verify in
   Phase 2 whether the hosted plugin makes the explicit ML Kit model dep redundant).
7. Gradle wrapper → 9.1.0. Update `local.properties` `flutter.sdk` to the new checkout.
8. Session env discipline from here on: `JAVA_HOME` → Zulu 17, PATH → `~/git/flutter-3.44/bin`,
   and `pkill -f '[G]radleDaemon'` when switching JDKs (the daemon caches its JDK).

**Gate:** `flutter pub get` still resolves (old constraints permitting) and
`./gradlew :app:tasks` configures without evaluation errors. No APK expected.
**Rollback:** revert the phase commit; `local.properties` back to `~/git/flutter`.

### Phase 2 — Dependency graph rewrite (pubspec; ~1–2 sessions incl. Phase 3)

In this order (each step keeping `flutter pub get` resolvable before the next):

1. **isar → isar_community 3.3.x** (+ `isar_community_flutter_libs`,
   `isar_community_generator`). First because isar_generator's analyzer pin is the
   hard codegen blocker — nothing regenerates until this lands.
2. **flutter_ffmpeg → ffmpeg_kit_flutter_new** (4.5.x, `full_gpl`); delete the
   `flutterFFmpegPackage` ext from the root Gradle file.
3. **wakelock fork → wakelock_plus**; delete the `wakelock_windows` override.
4. **Fork swaps per Phase 0 confirmations:** flutter_vlc_player → 7.4.4;
   flutter_inappwebview → 6.1.x; filesystem_picker → upstream 4.1.0 or patched fork;
   receive_intent → upstream 0.2.7 or namespaced fork; material_floating_search_bar →
   material_floating_search_bar_2; nowplaying fork + namespace; mecab_dart kept
   (namespace shim covers it, else vendor).
5. **Un-vendor ML Kit:** `google_mlkit_text_recognition: ^0.16.0` hosted; delete
   `vendor/`; check whether the explicit `text-recognition-japanese` Gradle dep is
   still needed (the vendored plugin declared recognizers compileOnly; hosted may
   differ) — keep it if in doubt, it is harmless.
6. **Mechanical bumps** — everything in the "Mechanical" class of the table above,
   plus flutter_html 3.0.0 final and share_plus 13.
7. **Prune `dependency_overrides`:** drop `collection`, `ffi`, `http`, `logging`;
   keep `freezed_annotation`/`gap` until `spaces` is dealt with; keep
   `record_mp3_plus` flagged for retest-then-drop.

**Gate:** `flutter pub get` resolves cleanly, zero git-ref errors, `flutter pub
outdated` reviewed and remaining holds documented in the pubspec comments.
**Rollback:** per-step commits; any swap that deadlocks resolution reverts to its fork
with a namespace shim as the fallback posture.

### Phase 3 — Codegen (with Phase 2's session budget)

1. slang 3→4 config migration; regenerate `strings.g.dart`.
2. `dart run build_runner build --delete-conflicting-outputs` — isar_community_generator,
   json_serializable, copy_with_extension, dart_mappable, full regen.
3. Review generated diffs, **especially the Isar schema outputs** — the generated
   schemas must be semantically identical (same collections, same property types/ids),
   since on-disk compatibility is the whole bet.

**Gate:** build_runner completes; Isar generated-schema diff reviewed and clean.
**Rollback:** regenerated files are committed separately from hand edits; revert is
mechanical.

### Phase 4 — Compile-fix sweep (~2–4 sessions; ends the non-buildable trench)

Ordered from mechanical to surgical:

1. `dart fix --apply` first (covers `MaterialState*` → `WidgetState*` — 11 hits /
   1 file — and other auto-fixables).
2. **Themes:** `useMaterial3: false` in both ThemeData; `DialogTheme(...)` →
   `DialogThemeData` (type change, compile break, mechanical) and same for
   cardTheme/tabBarTheme; ColorScheme role renames (`background` → `surface`; we build
   `ColorScheme.fromSwatch().copyWith(background: ...)` in both themes); `accentColor`
   4 hits. Raw `ThemeData(` constructions: 31 — sweep each.
3. `WillPopScope` → `PopScope` (`canPop` + `onPopInvokedWithResult`): 12 uses /
   11 files. Semantic migration, not find-replace; the exit-media confirm flow is the
   one needing real care.
4. `textScaleFactor` → `TextScaler`: 10 hits / 2 files. `toolbarOptions`
   (SelectableText) → `contextMenuBuilder`: 4 hits.
5. **ffmpeg call-site rewrite** (15 hits / 5 files): `FFmpegKit.execute()` → session
   `getReturnCode()`; `FFprobeKit.getMediaInformation()`; per-session `getOutput()`
   replaces `getLastCommandOutput()`; statistics via `FFmpegKitConfig.enableStatisticsCallback`
   or per-call callback. All call sites change shape; keep command strings byte-identical
   to the Phase 0 audit.
6. `Wakelock.` → `WakelockPlus.` (7 hits / 4 files); share_plus new API; just_audio /
   audio_session / slang API deltas; misc package breaks as the analyzer surfaces them.
7. **flutter_inappwebview 6 migration on sub-branch `toolchain-migration-webview`**
   (54 hits / 8 files): `InAppWebViewGroupOptions` → `InAppWebViewSettings`, merged
   callbacks, enum renames; `HeadlessInAppWebView`, `onConsoleMessage`,
   `callAsyncJavaScript` survive. Touches TTU reader (~3,600-line page), mokuro
   browse, browser source. Merge back when those compile.
8. flutter_vlc_player 7.4.4: API stated stable (`VlcPlayerController`, `getSpuTracks`,
   `setSpuTrack`) — expect small edits only.
9. R8/proguard check: `minifyEnabled true` under AGP 9 with the new plugin set —
   add keep rules if ffmpeg-kit/ML-Kit/Isar strip wrong.

**Gate (the big one):** `flutter analyze` zero errors; **`flutter build apk` succeeds**
(pipefail + sha1-freshness check per the build skill); APK installs and cold-launches
to the home screen on the Boox Palma 2 Pro. First delivered dev build (`+N` bump as
always).
**Rollback:** sub-branch revert for webview; otherwise phase-boundary commit.

### Phase 5 — Data-integrity verification (~1 session; hard gate)

The irreplaceable-user-data phase. Nothing merges until every box below is ticked.

1. **Isar on-disk compatibility:** open a **copy** of the real device DB under
   isar_community 3.3 (pull the Phase 0 `adb pull` copy into the app's data dir on a
   scratch install, or a harness build) — all 11 collections readable, spot-check
   record counts against the old build.
2. **Hive boxes** load with values intact (`is_dark_mode` dynamic-default gotcha noted;
   force-persisted values must survive).
3. **TTU IndexedDB continuity:** install the migration build **over** an existing
   1.4.0+25 install (`adb install -r`); open the TTU reader; the `books` database and
   reading positions must be intact under inappwebview 6 (data-directory continuity).
4. **Export/import bundle contract:** import a pre-migration bundle (and, if archived,
   a genuine 1.2.0-era bundle) into a fresh migration install; export from the
   migration build and re-import it; manifest schema unchanged or migration written.
5. jiyudoga single-mkv study-export handling spot-check.

**Gate:** all of the above green on the Palma. **If Isar data is unreadable, the
migration stops here** and the isar_community bet is re-examined — no workaround
shipping.
**Rollback:** device restored from the safety net (Section 4); branch state untouched
by device testing.

### Phase 6 — Full manual verification matrix (~1–2 sessions, device-heavy)

The complete matrix, run on the Boox Palma 2 Pro (primary):

| Area | What to verify |
|---|---|
| Dictionary | Import/lookup across installed languages; search, tap-to-look-up |
| TTU reader | Book opens, position kept, audio toolbar (all items incl. hidden-items config), lookup in reader |
| Tasker intents | All seven `shiroikuma.jisho.action.PLAYBACK_*` broadcasts drive the toolbar as before |
| Mokuro | Browse + lookup in mokuro volumes |
| Scanned PDF OCR | Source works end-to-end, results identical to 1.4.0+25 (hosted ML Kit vs vendored) |
| Player | Local + YouTube playback (vlc 7.4.4: retest background playback / keep-alive behavior changes noted in 7.4.0), subtitle tracks incl. PGS OCR, comparison mode, position persistence |
| Anki export | Card export incl. audio extraction (ffmpeg-kit path) and image; AnkiDroid API interop |
| Backup/restore | Round-trip + legacy bundle import (re-run of the Phase 5 checks on the final build) |
| Browser | Browser source, lookup |
| Permissions | First-run permission flows still function (permission_handler 12 under targetSdk 32) |
| E-ink visual pass | Full screen-by-screen pass on the Palma — even with M3 opted out, theme/type changes 3.13→3.44 can shift metrics; check the narrow-width fits (audio toolbar, popup menus) |

Secondary: install on the Huawei Mate XT, smoke test (launch, dictionary, player).

**Gate:** matrix green; 白い熊 signs off on the e-ink visual pass.
**Rollback:** fix-forward on the branch; device safety net still valid.

### Phase 7 — Docs, merge, release (~1 session)

1. Documentation updates, same commit series as the merge:
   - `CLAUDE.md`: toolchain table (Gradle 9.1.0 / AGP 9.0.1 / built-in Kotlin /
     compileSdk 36 / NDK inherited / **JDK 17 pin replacing the JDK 11 pin**, new
     SDK-checkout path), gotchas that changed.
   - `.claude/skills/build-and-release/SKILL.md`: JAVA_HOME → Zulu 17, Flutter SDK
     path, daemon-hygiene note updated (the `[G]radleDaemon` pkill rule survives).
   - `README` Building section.
   - `CHANGELOG.md`: user-visible notes (ML Kit un-vendored is invisible; note
     anything the matrix surfaced as changed behavior, e.g. vlc background playback).
   - Delete `TOOLCHAIN_MIGRATION_HANDOFF.md` (superseded) or mark it historical.
2. Tag `main` pre-merge (`pre-toolchain-migration`); merge `toolchain-migration`.
3. Resume normal dev builds off `main`; cut the release (suggested **1.5.0** — minor
   bump: large internal change, externally near-invisible) once a few days of daily
   driving pass without regression. Release per the standard skill (bare tag, clean
   pubspec, no-datetime APK name, GitHub release).

**Gate:** docs merged with the code (never trailing); release published.

## 6. Effort estimate

| Phase | Sessions |
|---|---|
| 0 Preparation | 1 |
| 1 Toolchain skeleton | 1 |
| 2+3 Dependencies + codegen | 1–2 |
| 4 Compile-fix sweep (incl. webview sub-branch) | 2–4 |
| 5 Data integrity | 1 |
| 6 Verification matrix | 1–2 (device-heavy, needs 白い熊) |
| 7 Docs/merge/release | 1 |
| **Total** | **8–12 working sessions** |

The webview migration (Phase 4 step 7) is the single largest line item and the most
likely overrun; the trench Phases 1–4 should be scheduled contiguously so the repo
does not sit unbuildable across long gaps.

## 7. Risk register

| # | Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|---|
| R1 | Isar on-disk format not actually readable by isar_community despite "same format" claim | Critical (user data) | Low–Med | Phase 5 hard gate on a DB **copy**; full safety net (bundle + raw pull); migration stops if red |
| R2 | TTU IndexedDB (`books`) lost moving to inappwebview 6 (data-directory change) | Critical (user library) | Medium | Phase 5 upgrade-in-place test before any wider install; export bundle carries TTU dumps as restore path |
| R3 | Webview API migration regressions in the ~3,600-line TTU reader page | High | High | Dedicated sub-branch; focused matrix rows (reader, mokuro, browser); revert-as-unit |
| R4 | FFmpeg 4.x → 8.1 CLI/behavior drift breaks command strings (not just the Dart API) | Medium | Medium | Phase 0 command audit as reference; per-feature retest (subtitles, thumbnails, Anki audio); `full_gpl` keeps codec superset |
| R5 | Legacy variant API removal breaks the versionCode/APK-rename port silently (wrong codes → device downgrade errors later) | Medium | High (it WILL break; risk is porting it wrong) | Explicit Phase 1 task; verify computed versionCode/versionName of the first Phase 4 APK via `aapt dump badging` |
| R6 | Pub resolution deadlock across the 60+ package graph | Medium | High | Phase 2 step order, per-step commits, temporary overrides as documented crutches |
| R7 | vlc 7.4 behavior changes (background playback, keep-alive removal) surprise the player UX | Medium | Medium | Named matrix row; fork diff in Phase 0 shows what the fork changed |
| R8 | AGP 9 built-in Kotlin friction with old third-party plugin builds | Medium | Medium | Namespace shim; `android.builtInKotlin=false` escape hatch (temporary); vendor as last resort |
| R9 | R8 under AGP 9 strips reflective code (ffmpeg-kit / ML Kit / Isar) in release builds only | Medium | Medium | Test release builds (we always build release); add keep rules on first symptom |
| R10 | E-ink visual regressions despite M3 opt-out (default metric/typography drift 3.13→3.44) | Medium | Medium | Dedicated visual pass row; narrow-width checks from CLAUDE.md remain the bar |
| R11 | mecab_dart / old native .so under NDK 28 (incl. future 16 KB page alignment) | Medium | Low–Med (targetSdk 32 defers the 16 KB mandate) | Namespace shim first; vendor + rebuild natives if load fails; 16 KB audit deferred to the targetSdk project |
| R12 | Shared-SDK breakage of other repos | Low | Avoided by design | Second SDK checkout; `~/git/flutter` untouched |
| R13 | youtube_explode_dart churn against live YouTube mid-migration | Low | Medium | Bump to current 3.x; treat YouTube breakage as ambient, not migration-caused, unless bisected |

## 8. Immediate next steps

Phase 0, on explicit go-ahead: install Zulu 17, make the `~/git/flutter-3.44` checkout,
create the branch, take the device safety net, and produce the two audit write-ups
(ffmpeg commands, fork diffs) that convert decisions 4–5 into confirmed picks.

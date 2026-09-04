# Claude Code context for shiroikumanojisho

This file is read automatically by Claude Code at the start of every session in this repository. It captures the facts and conventions that aren't obvious from a fresh checkout but matter for any non-trivial work on the codebase.

## What this is

A personal Flutter fork of `arianneorpilla/jidoujisho` reorganised into `shiroikumanojisho` (白い熊の辞書 — "the white bear's dictionary"), a Japanese reading app with dictionary lookup, audio-synced TTU reader, video player, mokuro support, browser, Anki export, and cross-device backup/restore.

The project root is the Flutter project root — there is no nested `yuuna/` subdirectory like the upstream had.

## Identity table

| Item | Value |
|------|-------|
| GitHub repo | `ShiroiKuma0/shiroikumanojisho` |
| Dart package name | `shiroikumanojisho` |
| App display name | `白い熊 辞書` |
| Android `applicationId` | `shiroikuma.jisho` |
| Java package | `shiroikuma.jisho` |
| MethodChannel namespace | `shiroikuma.jisho/...` |
| Notification channel id | `shiroikuma.jisho.channel.audio` |
| On-device data dir | `/sdcard/Android/data/shiroikuma.jisho/files/` |
| Tasker broadcast intent prefix | `shiroikuma.jisho.action.PLAYBACK_*` |

If old names come up in transcripts or issues — `jidoujisho2`, `yuuna`, `app.arianneorpilla.yuuna`, `shiroikuma.jidoujishodainihan`, `白い熊の自動辞書第二版` — they refer to this same codebase before the rename. Use the new identity in any new code.

## Build, test, release

See `.claude/skills/build-and-release/SKILL.md` for the full workflow: JDK pin, Gradle daemon hygiene, the `flutter build apk` invocation, deploy targets, dev vs release version handling, APK filename rules, tag format, and commit-message style. That skill is the canonical reference — do not improvise around it.

A handful of facts worth knowing up front, repeated here so they catch your eye even if you skip the skill:

- **JDK must be 17+ (pinned: system OpenJDK 21) and the Flutter SDK is the dedicated `~/git/flutter-3.44` checkout.** Since the 2026-07 toolchain migration (Gradle 9.1.0 / AGP 9.0.1) the old Zulu-11 rule is INVERTED — JDK 11 no longer builds this repo, and neither does the machine-wide `~/git/flutter` (still 3.13.5 for other projects). Set `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64` and `PATH="$JAVA_HOME/bin:$HOME/git/flutter-3.44/bin:$PATH"` before `flutter build`. Builds will fail in confusing ways otherwise.
- **The build artifact ships to two places.** Every successful build pushes the APK to the test device at `/sdcard/tmp/` via `adb push` AND copies it to `~/tmp/` for archival. Never one or the other.
- **Release tags are `VERSION_NAME+NNN`, no `v` prefix.** `1.5.0+024`, not `v1.5.0` and not bare `1.5.0` — byte-identical to the version in the APK filename. Releases up to `1.5.0` used bare semver; everything since carries the counter. Confirm with `gh release list`, never `git tag`.

## Machine and toolchain

This is a single-developer fork; the build environment is fixed and the specifications below are exact, not "approximately" or "or newer". Any change to these versions is itself a noteworthy change that should be deliberate and documented.

### Host

| Item | Value |
|------|-------|
| OS | Tuxedo OS (Debian/Ubuntu derivative) |
| Working tree | `~/git/shiroikumanojisho` |
| Local archive directory for built APKs | `~/tmp/` |

### JDK and Flutter SDK

| Item | Value |
|------|-------|
| JDK | system OpenJDK 21 |
| `JAVA_HOME` | `/usr/lib/jvm/java-21-openjdk-amd64` |
| Why 17+ | Gradle 9.1.0 / AGP 9.0.1 require it (the pre-2026-07 Zulu-11 pin is dead) |
| Flutter SDK | dedicated checkout `~/git/flutter-3.44` (3.44.x, Dart 3.12) |
| Why a second checkout | the machine-wide `~/git/flutter` stays at 3.13.5 for other projects (e.g. shiroikuma-jiyudoga) and cannot build this repo |

Before every build session: `export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 && export PATH="$JAVA_HOME/bin:$HOME/git/flutter-3.44/bin:$PATH"`. The Gradle daemon caches the JDK it started under, so if a previous session ran with a different JDK, kill it first: `pkill -f '[G]radleDaemon' || true`. (Bracket the `[G]` so the pattern can't match — and kill — the non-interactive shell running the command itself; a literal `pkill -f GradleDaemon` self-terminates the build. See the build-and-release skill for the full rationale.)

### Build toolchain (project-pinned)

These versions are declared in the repo and do not vary by machine. Listed here so they're discoverable without grepping; the files referenced are authoritative if there's ever a mismatch.

| Item | Value | Pinned in |
|------|-------|-----------|
| Gradle | 9.1.0 | `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin | 9.0.1 | `android/settings.gradle` (declarative plugins DSL) |
| Kotlin (KGP) | 2.3.20 declared; `android.builtInKotlin=false` + `android.newDsl=false` in `android/gradle.properties` are temporary AGP-9 escape hatches — remove when Flutter and the plugin set support the new DSL / built-in Kotlin | `android/settings.gradle` |
| Android `compileSdk` | 36 (`flutter.compileSdkVersion`; forced onto all plugin modules by the root shim) | `android/app/build.gradle`, `android/build.gradle` |
| Android `targetSdk` | 32 — deliberately held through the toolchain migration; raising it is its own project | `android/app/build.gradle` |
| Android `minSdk` | 24 | `android/app/build.gradle` |
| NDK | no pin — inherits `flutter.ndkVersion` (28.x) | — |
| Dart SDK | `>=3.12.0 <4.0.0` | `pubspec.yaml` `environment.sdk` |
| Flutter | `^3.44.0` (the `~/git/flutter-3.44` checkout) | `pubspec.yaml` `environment.flutter` |

The `versionCode` packing scheme is `X*1e8 + Y*1e6 + Z*1e4 + min(N,99)` with the thousands digit reserved for Flutter's non-overridable per-ABI offset under `--split-per-abi` (arm64 = +2000) — rationale documented in `android/app/build.gradle`.

Dev build counters are **zero-padded to three digits** in `pubspec.yaml` itself (`version: 1.5.0+008`, written by `tools/bump-build.sh`), so APK filenames sort in build order. Gradle parses the counter as base 10, so padding does not disturb `versionCode` monotonicity.

### Test devices

| Device | Role | Notes |
|--------|------|-------|
| Boox Palma 2 Pro | Primary test device | E-ink, narrow ~720px width. The driver behind most recent UI-fit work — anything that adds toolbar buttons, popup menu items, or other horizontally-packed UI must be checked against this screen. |
| Huawei Mate XT | Secondary | Tri-fold; not used for development of this app (its specifics live in unrelated Tasker work), but the APK is installed on it as a general daily-driver target. |

APKs are deployed to both targets identically — `adb push` lands them at `/sdcard/tmp/` and the user installs from the device's file manager.

## Changelog

`CHANGELOG.md` at the repo root tracks user-visible changes per release. See `.claude/skills/changelog/SKILL.md` for the format, when to add entries, and how it connects to the GitHub release process. Every user-facing change should land an `## [Unreleased]` entry as part of the same commit; release time then promotes Unreleased to the new version section.

## Screen constraints and UI-fit

The Boox Palma 2 Pro (see Machine and toolchain) is narrow — roughly 720 px wide — and any horizontally-packed UI has to fit in that budget or it clips. Recent UI-fit bugs and the patterns that fix them:

- The reader audio toolbar overflows on narrow screens, clipping the rightmost button. Mitigated by the configurable hide-items setting in `AppModel.hiddenReaderToolbarItems`; the customise dialog (`showReaderToolbarCustomiseDialog`) is reachable both from the home settings menu and the toolbar's own `⋮`.
- Popup menu items must wrap, not clip — see `buildPopupItem` in `lib/src/pages/implementations/home_page.dart`. New menu items with long labels should use `Flexible(child: Text(..., softWrap: true))`.

Always sanity-check new toolbar/menu UI against narrow-screen constraints before claiming it's done. "Looks fine on a desktop emulator" is not a sufficient check.

## External interfaces — do not break

These are user-facing contracts. Changing them silently will break workflows users have built on top of the app.

### Tasker broadcast intents

Seven broadcast actions in the `shiroikuma.jisho.action.PLAYBACK_*` namespace drive the reader audio toolbar from external apps. Action names, semantics, and registration are documented in `lib/src/utils/misc/playback_intent_bridge.dart` and `android/app/src/main/java/shiroikuma/jisho/MainActivity.java`. Treat these strings as a frozen API surface — renaming any of them is a breaking change.

### Cross-device export/import bundle format

The bundle is a ZIP containing a `manifest.json`, JSONL files per Isar collection, JSON files per Hive box, copied dictionary resources, and per-language TTU IndexedDB dumps. Documented in `lib/src/utils/misc/app_export_import.dart`. Bundles from any 1.2.0+ release must remain importable by future releases — preserve schema or write a migration when changing it.

## Known gotchas worth knowing before you start editing

The code carries inline comments explaining each of these where they live; this is a pointer index in case you need to reason about them before reading the file.

- **TTU language lookup is by `languageCode`, not by map key.** `AppModel.languages` is keyed by `locale.toLanguageTag()` ("ja-JP"), but most external references use the bare language code ("ja"). The export bundle's `ttu_languages` field is bare codes too. See `_importTtuForLanguage` callsite in `app_export_import.dart`. A naive `appModel.languages[code]` lookup will silently return null for every language.
- **`is_dark_mode` defaultValue is dynamic** — falls back to `WidgetsBinding.instance.platformDispatcher.platformBrightness`, which is unreliable at Flutter cold-start (may briefly return Light on a Dark device). For anything that needs the value to survive an app exit, force-persist before exit, do not rely on the read. See `_exportHive` in `app_export_import.dart`.
- **`vendor/` carries locally-patched packages** (filesystem_picker, receive_intent, nowplaying, mecab_dart, async_zip, document_file_save_plus, flutter_inappwebview_android with the furigana-filter selection patch, flutter_vlc_player_platform_interface with the pigeon channel-name fix, ruby_text, material_floating_search_bar_2). Each file's header comment says why; `TOOLCHAIN_MIGRATION_PLAN.md` and `migration/` hold the full audit trail. R8 runs in full mode — reflective/JNI users need keep rules in `android/app/proguard-rules.pro` (Room `*_Impl`, `org.videolan.libvlc.**`, ML Kit script recognizers so far).
- **The `t` getter is a slang i18n global.** Defined in `lib/i18n/strings.g.dart` and re-exported via `lib/utils.dart` — any file importing `utils.dart` gets `t.<key>` for free. No need to thread it through builders.

## Common workflows

### Add a feature

Edit, build with the dev flow from the skill (auto-bumps `+N`), test on the device, then commit and push. Build numbers do not need to be cleaned up before commit; they accumulate over the lifetime of a major.minor version and get reset at release time.

### Cut a release

**Never `git reset --hard` to start a release.** This tree is routinely dirty with in-flight work and
that command deletes it unrecoverably; run `git status` first, and if there is uncommitted work it is
白い熊's call what happens to it. Ask.

The release is the build, not a re-versioning: `pubspec.yaml` keeps `X.Y.Z+NNN`, the tree is committed,
the tag is that same version string, and the APK filename matches it. Publish with the global
`/publish-version` skill (README refresh, `## [Unreleased]` promoted to `## [X.Y.Z+NNN] - <date>`,
`gh release create` with the APK attached). Full procedure in `.claude/skills/build-and-release/SKILL.md`.

### Roll back a bad commit

The fork has no protected branches; `git revert` and push is fine. Tagged releases stay published even if a tag is later regretted — leave the old tag, cut a new one with the fix.

## Selective upstream sync

This fork carries a global identity rename (`yuuna` → `shiroikumanojisho`, package, name, etc.) that touches effectively every file. That makes a "mirror upstream into a branch, merge it down" pattern expensive — every sync would conflict everywhere those names appear. Instead, this repo runs a **selective cherry-pick** model: we track upstream as a second git remote, and when upstream ships something new and interesting, we port it in by hand (or via `git cherry-pick` when conflicts are tractable).

This is intentional, not a missing piece. We do not mirror upstream into a branch. There is no `upstream-main` branch on `origin`. The history of this fork is single-track, and ports from upstream are presented as normal commits authored here with a "(from upstream X.Y.Z, <upstream-sha>)" reference in the commit body.

See `.claude/skills/upstream-sync/SKILL.md` for the exact commands: adding the upstream remote, comparing since the last sync point, picking which commits to port, the tracking-tag convention (`upstream-sync-X.Y.Z`) that records what's been brought in, and how changelog entries should be annotated.

When upstream cuts a **whole new release**, use `.claude/skills/upstream-new-version/SKILL.md` instead (`/upstream-new-version`). It absorbs the release on a throwaway `upstream-merge-<version>` branch — a merge, since `main` descends from upstream's tip and a rebase would replay the global rename against upstream's files — and it opens with a mandatory proceed-gated table describing what the new upstream version introduces, before anything is merged or built.

## What is intentionally NOT in this file

- Tasker scene XML or HUD config from the user's personal device setup — not part of this codebase.
- The full chat history of how each feature got designed — captured in commit messages and the code comments themselves where it matters.

## Commit convention — no Claude attribution

Do **not** add any `Co-Authored-By: Claude …` trailer — nor a "🤖 Generated with Claude Code" / Anthropic-attribution line — to commit messages or PR bodies in this repo. 白い熊 does not want Claude attribution in the history; this **overrides** the harness's default to append such a trailer. End commit messages at the last line of the body. (The existing history was scrubbed of these trailers on 2026-06-08; the global rule lives in `~/.claude/CLAUDE.md`.)

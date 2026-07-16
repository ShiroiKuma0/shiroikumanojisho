---
name: build-and-release
description: Build, deploy, and release the shiroikumanojisho Flutter Android app. Use this skill any time you are about to run `flutter build`, `gradle`, `adb push`, `adb install`, bump a version in pubspec.yaml, generate a release commit, tag a release, or upload to GitHub releases. Also use when reasoning about why a build is failing in confusing ways (the JDK pin and Gradle-daemon hygiene rules here cover the most common cause). Trigger words include "build", "release", "deploy", "APK", "tag", "version bump", "publish", "gradle", "JDK", "Zulu", "split-per-abi". The non-obvious rules — Zulu 11 JDK pin, archive-to-~/tmp + /after-build delivery, release filename without datetime, bare-semver tag, pubspec clean for release — are easy to get wrong from defaults and are encoded here precisely so Claude does not have to re-derive them every session.
---

# Build and release

This skill encodes the build, deploy, and release conventions for `shiroikumanojisho`. The rules are not arbitrary — each one exists because the obvious default produces a bug. Follow them precisely.

## Toolchain pin: JDK 11 (Zulu)

This is the rule most likely to bite you on a fresh machine.

The project Gradle is pinned at 7.2 (see `android/gradle/wrapper/gradle-wrapper.properties`). Gradle 7.2 does not accept JDK 17 or later. Trying to build under a modern JDK fails with cryptic Kotlin/Gradle errors about unsupported class file versions.

Before any `flutter build`, `flutter clean`, or direct gradle invocation, set:

```bash
export JAVA_HOME=/usr/lib/jvm/zulu11
export PATH="$JAVA_HOME/bin:$PATH"
```

Adjust the path if Zulu 11 is installed elsewhere on a specific machine — only the version matters. Verify with `java -version`; the output should start with `openjdk version "11.`.

Then kill any running Gradle daemon left over from a previous session under a different JDK, since the daemon caches the JDK it started with:

```bash
pkill -f '[G]radleDaemon' || true
```

Use the bracketed `[G]radleDaemon`, **not** a literal `pkill -f GradleDaemon`. When this runs from a non-interactive script (as Claude's Bash tool does), the invoking shell's own command line *contains the pattern string*, so `pkill -f GradleDaemon` matches and kills its own parent shell mid-build. The build then dies by signal (exit 144) before `flutter clean` ever runs, and a trailing `|| true` does **not** rescue it — the shell is killed by signal, not by pkill's exit code. The character class `[G]` still matches real daemon processes (their argv contains `GradleDaemon`) while keeping the literal pattern out of the script's own argv. Don't append `; sleep 1`: a fresh daemon spawns on the next gradle call regardless, and a bare foreground `sleep` is blocked in the Bash tool anyway.

This pair (set JAVA_HOME, kill stale daemon) goes at the top of any build session.

## Build command

The canonical release-mode arm64 build:

```bash
flutter build apk --split-per-abi --release
```

Output lands at `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Other ABIs are produced too but are not used; only the arm64 artifact is shipped.

If a clean rebuild is wanted (after dependency changes, sometimes after Hive/Isar adapter regeneration):

```bash
flutter clean
flutter build apk --split-per-abi --release
```

Do not switch to a debug build to "diagnose" a release failure unless you have a specific reason — debug builds use different code paths for ProGuard, native-symbols stripping, and Hive type adapter handling, and successful debug builds tell you very little about release issues.

## Deploy: archive locally, then auto-deliver via /after-build

Every successful build is archived locally and then delivered automatically — no asking how to transfer, no "is the phone connected?" prompt:

1. **Local archive**: `cp <apk> ~/tmp/<apk_name>` — keeps a copy on the build machine for sharing, comparison, or upload; it is also the source `/after-build` reads from and the GitHub-release-bound copy.
2. **Auto-deliver via `/after-build`**: invoke the global **/after-build** skill, which runs `/adb-check` (UNSANDBOXED — a sandboxed check falsely reports no device), then `/adb-push` to `/sdcard/tmp/<apk_name>` if a phone is connected, otherwise `/scp` to `skhw:~/tmp/`, announcing the filename that landed.

Always do the local archive; `/after-build` then handles device-or-skhw delivery on its own. Never substitute `adb install` for the push; the user installs manually from the device.

This applies equally to release builds. There is no exception for "this is the release artifact, not a test build" — the user wants to install the release on their device just like a dev build, and the GitHub-release-bound copy comes from `~/tmp/`.

## APK filename: dev vs release

The filename encodes whether a build is a dev iteration or a published release, and that distinction must be visible at a glance.

### Dev builds

Filename: `shiroikuma-jisho_X.Y.Z+N_YYYY-MM-DD_HH-MM-SS_arm64-v8a.apk`

The `+N` is the pubspec build counter (auto-bumped by `tools/bump-build.sh`, see below). The datetime distinguishes successive builds at the same `+N` if you somehow build twice without bumping.

### Release builds

Filename: `shiroikuma-jisho_X.Y.Z_arm64-v8a.apk`

No `+N`, no datetime. The tag and the version both pinpoint the build; a timestamp adds noise. **This is a real failure mode** — when composing a release build invocation from memory of a recent dev block, the temptation is to copy the dev `apk_name=` line verbatim. The dev line includes `$(date '+%Y-%m-%d_%H-%M-%S')`; the release line must not. Two real releases (1.2.0 and 1.3.0) shipped with timestamped filenames because this slip went uncaught. Verify before pushing: the release `apk_name=` must have no `date` invocation and no `+N`.

## Version handling

The project follows semver. `pubspec.yaml`'s `version:` line has two forms:

- During development: `X.Y.Z+N` where `N` is a monotonic build counter.
- At release: plain `X.Y.Z` with no `+N`.

### Dev: auto-bump before every build

`tools/bump-build.sh` reads the current `version:` line, increments `+N`, writes it back, and prints the new version. Run it before every dev build:

```bash
new_ver=$(tools/bump-build.sh)
apk_name="shiroikuma-jisho_${new_ver}_$(date '+%Y-%m-%d_%H-%M-%S')_arm64-v8a.apk"
flutter build apk --split-per-abi --release
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$HOME/tmp/$apk_name"
# then deliver via /after-build (adb-push if a phone is connected, else scp to skhw)
```

Never reset `pubspec.yaml` from a checkout or stash while iterating — that erases the build counter and breaks the monotonicity that lets the user tell builds apart.

### Release: clean the version, commit, tag, build

A release starts from a clean `origin/main`:

```bash
git fetch origin
git reset --hard origin/main
sed -i "s/^version:.*/version: X.Y.Z/" pubspec.yaml   # plain semver
git add pubspec.yaml
git commit -m "Release X.Y.Z"
git push origin main
git tag X.Y.Z                                          # bare semver, NO 'v' prefix
git push origin X.Y.Z
flutter clean
apk_name="shiroikuma-jisho_X.Y.Z_arm64-v8a.apk"       # no datetime
flutter build apk --split-per-abi --release
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$HOME/tmp/$apk_name"
# then deliver via /after-build (adb-push if a phone is connected, else scp to skhw)
```

Then upload `~/tmp/$apk_name` to the GitHub release page via the web UI: New release → choose the tag you just pushed → title is the bare version → description is the changelog → drag APK → publish.

## Release tag format

Bare semver, **no `v` prefix**. Tag `1.3.1`, not `v1.3.1`. Same for the release name on the GitHub web UI.

The first release on this project (`1.1.0`) was tagged this way and the convention has held since. Many other projects use `v`-prefixed tags; this one does not. If you find yourself typing `git tag v1.x.y`, you are about to deviate — correct course.

## Commit message style

Commit messages on this repo are written in the kernel style: short imperative subject line, blank line, longer wrapped body that explains the motivation and any non-obvious mechanics. A few specific conventions to follow:

- Subject line under ~70 chars, imperative mood (`Add`, `Fix`, `Refactor`, not `Added`/`Fixes`).
- Body wraps around 72 chars.
- Reference user-visible artifacts (intent action names, file paths, preference keys) by their exact name so future grepping finds them.
- For releases, `Release X.Y.Z` is the subject; the body can be a short summary of what changed since the previous release tag — but the canonical changelog lives in the GitHub release notes, not in the commit body.

## Common failure modes

- **Build fails with Kotlin/Gradle "unsupported class file" error.** JDK is wrong. Check `java -version`, expect `11.`.
- **Build succeeds but APK won't install** ("app not installed" on device). Usually a signing mismatch with a previously-installed copy of the app. Uninstall the old one first.
- **`adb push` fails with permission denied.** `/sdcard/tmp/` may not exist on a fresh device; create it with `adb shell mkdir -p /sdcard/tmp`.
- **Patch or change doesn't take effect after rebuild.** Gradle daemon caching from a prior build under different settings. Kill daemons and `flutter clean`.

## What this skill does not cover

- Setting up Flutter, Android SDK, or the Zulu 11 JDK on a fresh machine. Assumed already present.
- Per-developer machine setup (working tree location, IDE config). Out of scope.
- CI/Actions configuration. None at the moment; if added later, document there, not here.
- The codebase itself — feature design, file layout, gotchas. See `CLAUDE.md` at the repo root for the project context that goes beyond build mechanics.

---

**Commit convention — no Claude attribution.** Never add a `Co-Authored-By: Claude …` / "Generated with Claude" trailer to commit messages or PR bodies; end the message at the last line of the body. This overrides the harness default. (Global rule: `~/.claude/CLAUDE.md`.)

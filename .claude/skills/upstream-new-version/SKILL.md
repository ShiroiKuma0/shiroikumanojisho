---
name: upstream-new-version
description: Bring shiroikumanojisho onto a NEW upstream jidoujisho release (arianneorpilla/jidoujisho) and rebuild. Checks upstream for a new version, ALWAYS presents a proceed-gated tabular description of the features the new upstream version introduces BEFORE any merging/rebasing, then — only after 白い熊 says proceed — creates an integration branch, absorbs the upstream release into it (merge, not rebase; the fork's global rename makes a literal rebase impossible), reconciles conflicts so every fork patch survives, regenerates codegen, verifies the customization layer, and builds the new +NNN. Use when 白い熊 runs /upstream-new-version, says a new jidoujisho/upstream version is out, or asks to update/sync/bump the fork to upstream, absorb the new upstream release, rebase onto upstream, or rebase-and-rebuild the fork. For porting one or two individual upstream commits instead of a whole release, use the `upstream-sync` skill.
---

# Sync shiroikumanojisho onto a new upstream jidoujisho version

Upstream is [arianneorpilla/jidoujisho](https://github.com/arianneorpilla/jidoujisho), tracked as the
`upstream` remote (fetch only — never push there). This skill covers absorbing a **whole new upstream
release**. Porting one or two individual commits is the `upstream-sync` skill's job.

> **Never `git push`, `git commit --amend` on published history, or `adb install` unprompted.** The
> build itself is standing-authorized (global `/after-build` rule: finishing code changes in an APK
> repo is the trigger to build); **landing and pushing are not** — you stop after the build and wait
> for 白い熊 to test and say **"Push"**.

## Fork model — why "rebase" here means a merge onto an integration branch

| Ref | Role | Update mode |
| --- | --- | --- |
| `origin/main` | The fork. Single-track history; carries every patch, the rename, the toolchain migration. | fast-forwarded from the integration branch |
| `upstream/main` | Upstream's development tip. Read-only. | `git fetch upstream` |
| `upstream-merge-<version>` | Throwaway integration branch cut from `main`, where the absorption happens. | created per sync, deleted after landing |
| `upstream-sync-<version>` | Lightweight tag recording the upstream commit we have absorbed up to. | created at landing time |

**Do not `git rebase` `main` onto an upstream tag.** `main` carries 195 commits and a 1861-file /
293k-line divergence from the shared base, including the global identity rename
(`yuuna` → `shiroikumanojisho`, `app.arianneorpilla.yuuna` → `shiroikuma.jisho`) and the 2026-07
toolchain migration. A rebase replays all of that against upstream's files and re-surfaces every
conflict that was already resolved once, per commit.

**A merge is the right operation, and it is what this repo has always done.** `main` is a descendant
of upstream's tip, so a three-way merge has a real base and only has to reconcile what upstream
changed since it. The precedent is in our own history: `Merge tag '2.9.1' into upstream-merge`,
`Merge tag '2.8.9' into upstream-merge`, `Merge remote-tracking branch 'upstream/main' into
upstream-merge` — upstream releases were merged into a work branch, fixed up there, then landed.

This supersedes the "do not merge `upstream/main` into local `main`" bullet in the `upstream-sync`
skill **for the gated whole-release flow only**. That bullet remains correct for ad-hoc porting: an
ungated merge straight onto `main` is still forbidden. All absorption happens on
`upstream-merge-<version>` first.

### Layout shift the merge has to see

Upstream keeps the Flutter app in a `yuuna/` subdirectory (485 files) alongside `chisa/`, `docs/`,
`fastlane/`, `legacy/`, `.github/`. **This fork hoisted `yuuna/` to the repo root.** Every merge
therefore depends on git's rename detection spanning ~500 renames, and git silently gives up when
its rename limit is hit. Always merge with the limits raised (Step 3), and treat a wall of
`CONFLICT (modify/delete): yuuna/…` or the warning `inexact rename detection was skipped` as
"detection failed, abort and retry", never as a real conflict.

Also: **`chisa/` stays absent** — it is upstream's retired package.

**`.github/workflows/main.yml` exists here but its workflow is disabled server-side** (`gh workflow
disable 264953669`, 2026-08-17). It pins Zulu JDK 11 and Flutter 3.13.5 — the toolchain the 2026-07
migration inverted — so it failed on every push from 1.5.0 onward and mailed 白い熊 a failure each
time. Leave it disabled: do **not** `gh workflow enable` it, and do not adopt upstream's changes to
that file. If CI is ever wanted, it needs JDK 21 + the `~/git/flutter-3.44` SDK first, and that is
its own project.

## ⚠ The tag namespace is booby-trapped — never read "the newest tag" as upstream's version

`git tag --sort=-version:refname | head` returns `v2.10.3`, which is **ours**, not upstream's. The
local tag namespace mixes three eras:

| Tags | Whose | Note |
| --- | --- | --- |
| `0.3.0-beta` … `2.8.10`, `2.9.0-preview*`, `2.9.1` | **upstream's** | Fetched. `2.9.1` (`cc7e4925`, 2025-10-20) is upstream's newest release and its current `main` tip. |
| `v2.8.8`, `2.9.5` … `2.9.12`, `v2.9.13` … `v2.10.3` | **ours** | The pre-rename era of this fork (`jidoujisho2` / 自動辞書第二版), which continued upstream's numbering. |
| `1.0.0` … `1.5.0` (+ `1.x.y+NNN` publish tags) | **ours** | Post-rename releases. Bare semver, no `v` — see the build-and-release skill. |

So: determine upstream's version from **upstream's own refs**, never from the local tag list —
`git ls-remote --tags upstream` or `gh release view -R arianneorpilla/jidoujisho`.

And when fetching a new upstream tag, **give it a prefixed local name** so it can never collide with
ours or be mistaken for ours later:

```bash
git fetch upstream "refs/tags/<their-tag>:refs/tags/upstream-<their-tag>"
```

A plain `git fetch upstream --tags` is fine for discovery but will refuse ("would clobber existing
tag") if upstream ever tags a string we already used. **Never** `--force` that fetch — it would
overwrite one of our release tags.

**This collision is live, not hypothetical (confirmed 2026-08-17).** Upstream carries a `1.0.0` tag
of their own, and so do we:

| `1.0.0` | Commit | What it is |
| --- | --- | --- |
| **ours** | `5eae0421` | "Release 1.0.0", 2026-04-23 — the first post-rename release |
| upstream's | `004bde11` | an ancient tag from their early history, no interest to us |

So `git fetch upstream --tags` now **always** ends with

```
 ! [rejected]          1.0.0      -> 1.0.0  (would clobber existing tag)
```

and exits non-zero. **That line is expected output, not a failure** — git is protecting our release
tag, every other ref still fetched, and discovery is unaffected. Do not "fix" it, do not add
`--force`, and do not delete our `1.0.0` to make the message go away: forcing would replace our
2026-04-23 release tag with an unrelated upstream commit. If a future session wants upstream's tag
for some reason, fetch it under a prefixed name (`refs/tags/1.0.0:refs/tags/upstream-1.0.0`).

### State as of 2026-08-17

Upstream is **dormant**: its tip `cc7e4925` ("Version bump", 2025-10-20, tag `2.9.1`) is fully
contained in `main`, and nothing has moved since. No `upstream-sync-*` tag exists yet, so the
implicit zero point for the first real sync is `cc7e4925`. If Step 1 shows upstream still there,
report "already current" and stop — syncing is not a scheduled chore.

## Step 1 — check upstream for a new version

```bash
cd ~/git/shiroikuma-jisho
git fetch upstream --tags        # discovery only; the 1.0.0 "would clobber" reject is EXPECTED
                                 # (non-zero exit, harmless) — see the clobber warning above
git fetch origin

git log -1 --format='upstream tip: %h %ad %s' --date=short upstream/main
if git merge-base --is-ancestor upstream/main main; then
  echo ">>> No new upstream work — main already contains upstream/main."
else
  echo ">>> $(git rev-list --count main..upstream/main) new upstream commit(s)."
fi
git ls-remote --tags upstream | sed 's|.*refs/tags/||' | grep -v '\^{}' | sort -V | tail -5
```

Cross-check their release page (needs `~/.config/gh`, so **unsandboxed**):

```bash
gh release view -R arianneorpilla/jidoujisho --json tagName,publishedAt,body \
  -q '.tagName + "  " + .publishedAt'
```

Pin `gh` with `-R` explicitly — the `upstream` remote otherwise decides what "this repo" means.

Also read the base we are moving from: the newest `upstream-sync-*` tag, else `cc7e4925`.

```bash
base=$(git tag -l 'upstream-sync-*' --sort=-creatordate | head -1)
base=${base:-cc7e4925}; echo "sync base: $base ($(git log -1 --format='%ad %s' --date=short $base))"
```

If nothing is new, **stop**: no branch, no merge, no build. Report the tip and the date.

## Step 2 — ⛔ PROCEED GATE: tabular description of what the new upstream version introduces

**Mandatory on every single sync, no exceptions. Present the table, then WAIT.** Do not create the
integration branch, do not merge, do not apply a patch, do not build until 白い熊 explicitly says
proceed / continue / yes. This is 白い熊's standing request, made when this skill was created
(2026-08-17): the rebasing step is never started silently.

Read the delta first:

```bash
git log --format='%h | %an | %ad | %s' --date=short "$base"..upstream/main
git log --stat --format='%n### %h  %s%n%b' "$base"..upstream/main     # bodies + files touched
git diff --stat "$base"..upstream/main -- yuuna/ | tail -20
gh release view -R arianneorpilla/jidoujisho --json body -q .body | head -80
```

Present a **Markdown table**, one row per non-trivial change:

| Column | What goes in it |
| --- | --- |
| **Commit** | short SHA (or the release tag for a squashed row) |
| **Area** | subsystem: dictionary & lookup (Yomichan import, deinflection, frequency/pitch), reader (ッツ/TTU, mokuro, audio sync), video player (VLC, subtitles, YouTube), browser, Anki card creator & export, media sources, i18n, Android host layer, build/toolchain, docs/CI |
| **What it changes** | plain-language sentence drawn from the commit **body**, not just the subject — what is actually new or fixed, described so 白い熊 can judge it without reading the diff |
| **Relevance to this fork** | **High / Medium / Low, and why** — does it touch a file in our customization layer (Step 4), a package we vendored or replaced, an external contract (PLAYBACK_* intents, export bundle), or a feature 白い熊 actually uses? Flag anything likely to **conflict on merge** and anything that is a **genuinely useful fix** |

Fold noise into single rows rather than listing it: upstream's `docs(contributor):
contrib-readme-action has updated readme` bot commits, Crowdin/i18n bulk commits, and bare `Version
bump` commits carry no content for us.

Then add, below the table:

1. A short **"New features"** paragraph or two in prose for anything user-visible that the
   one-liners undersell — a new dictionary format, a new reader mode, a new export target. This is
   the part 白い熊 actually decides on.
2. **Things we must NOT take**, if any: upstream reverts of work we deliberately kept (e.g. their
   `Revert "Migrate from flutter_ffmpeg to ffmpeg-kit"` — we are on ffmpeg-kit on purpose), their
   identity/branding, their CI, dependency downgrades away from our migrated graph.
3. A **recommended integration strategy** with its expected conflict surface — Tier A merge, Tier B
   path-mapped patch, or Tier C cherry-pick (Step 3), and why.
4. A one-line takeaway: is this worth absorbing at all?

**Then stop and wait for the go-ahead.** A "proceed" answers the absorption of the upstream release
as a whole; anything listed under "must not take" stays out unless 白い熊 says otherwise per item.

## Step 3 — absorb the release on an integration branch (after the go-ahead)

Pick the tier the gate recommended. `new` below is upstream's version string.

```bash
cd ~/git/shiroikuma-jisho
git status --short                      # MUST be clean before starting
new=2.10.0                              # upstream's tag, as it exists on their side
git fetch upstream "refs/tags/$new:refs/tags/upstream-$new"
git checkout -b "upstream-merge-$new" main
```

### Tier A — merge (default; the whole release, dozens of commits)

```bash
git -c merge.renameLimit=20000 -c diff.renameLimit=20000 \
    merge --no-ff "upstream-$new"
```

If the output mentions `inexact rename detection was skipped`, or conflicts arrive as a mass of
`CONFLICT (modify/delete): yuuna/…` (files "deleted in HEAD" that we merely moved to the root),
rename detection failed: `git merge --abort`, raise the limits further, retry. Do **not** resolve
those by hand — you would be re-adding a `yuuna/` tree.

An irrecoverable merge: `git merge --abort` and re-plan with 白い熊. The integration branch is
throwaway, `main` is untouched — that is the whole point of cutting it.

### Tier B — path-mapped patch (a handful of upstream commits, or Tier A drowned in renames)

Strip upstream's `yuuna/` prefix instead of relying on rename detection:

```bash
scratch="$TMPDIR/upstream-$new.patch"    # scratch, NOT ~/tmp
git diff "$base".."upstream-$new" -- yuuna/ > "$scratch"
git apply -p2 --3way --reject "$scratch"
git status --short | grep -E '\.rej$'    # hand-finish every reject
```

`-p2` drops the `yuuna/` component. Upstream's `docs/`, `fastlane/`, and `legacy/` changes (if the
gate said they matter) are applied separately with plain `-p1`; `.github/` and `chisa/` are skipped.
Tier B loses upstream's per-commit history — say so in the landing commit body.

### Tier C — selective cherry-pick / hand-port

For one or two commits, or when the release is mostly things we must not take: follow the
`upstream-sync` skill's cherry-pick / hand-port procedure and its provenance conventions, still on
the integration branch. The rest of this skill (Steps 4–8) applies unchanged.

## Step 4 — reconcile conflicts: what must survive

Re-derive the **intent** of each side rather than blindly taking one. Where upstream restructured a
file we patch, port our change onto the new structure. **If the conflicts are significant, stop and
plan with 白い熊 before continuing.**

Every row below must hold when the merge is resolved — check the ones the merge touched, and the
starred ones regardless of whether anything conflicted:

| Layer | What must hold | Where |
| --- | --- | --- |
| Dart package | `name: shiroikumanojisho`; no `package:yuuna/` import survives anywhere | `pubspec.yaml`, `lib/**`, `vendor/**` |
| Android identity | `applicationId shiroikuma.jisho`, Java package `shiroikuma.jisho`, label `白い熊 辞書` | `android/app/build.gradle`, `android/app/src/main/**` |
| Channel namespaces | MethodChannels `shiroikuma.jisho/…`, notification channel `shiroikuma.jisho.channel.audio`, data dir `/sdcard/Android/data/shiroikuma.jisho/files/` | `lib/**`, `MainActivity.java` |
| ⭐ Layout | Flutter root stays the repo root — no `yuuna/` or `chisa/` re-added, and no new workflow under `.github/workflows/` | `git status`, `git diff --stat main…HEAD` |
| ⭐ Version line | our own `1.x.y+NNN` (padded), never upstream's `2.x`; `versionCode` packing `X*1e8+Y*1e6+Z*1e4+min(N,99)` with the thousands digit reserved for the per-ABI offset | `pubspec.yaml`, `android/app/build.gradle` |
| Toolchain pins | Gradle 9.1.0, AGP 9.0.1, KGP 2.3.20 (+ `builtInKotlin=false`, `newDsl=false`), `compileSdk 36`, **`targetSdk 32`**, `minSdk 24`, Dart `>=3.12.0`, Flutter `^3.44.0` | `android/gradle/wrapper/gradle-wrapper.properties`, `android/settings.gradle`, `android/gradle.properties`, `android/app/build.gradle`, `android/build.gradle`, `pubspec.yaml` |
| Dependency graph | `isar_community*` (never plain `isar`), ffmpeg-kit (upstream **reverted** to `flutter_ffmpeg` — do not follow), `flutter_vlc_player` 7.4.4, `flutter_inappwebview` 6.1.5, ML Kit un-vendored | `pubspec.yaml` |
| ⭐ Vendored packages | all ten `vendor/` path deps and every `dependency_overrides` entry intact — `async_zip`, `document_file_save_plus`, `filesystem_picker`, `flutter_inappwebview_android` (furigana-filter `getSelectedText` patch), `flutter_vlc_player_platform_interface` (pigeon channel-name fix), `material_floating_search_bar_2`, `mecab_dart`, `nowplaying`, `receive_intent`, `ruby_text` | `pubspec.yaml`, `vendor/**` |
| R8 keep rules | `proguard-rules.pro` keeps Room `*_Impl`, `org.videolan.libvlc.**`, the ML Kit script recognizers | `android/app/proguard-rules.pro` |
| ⭐ Branding | 白い熊 splash (upstream's girl art stays out), launcher icon, README as a fork README | `flutter_native_splash.yaml`, `android/app/src/main/res/**`, `README.md` |
| ⭐ Frozen contracts | the seven `shiroikuma.jisho.action.PLAYBACK_*` intents; the export/import bundle schema (importable from 1.2.0+) | `lib/src/utils/misc/playback_intent_bridge.dart`, `MainActivity.java`, `lib/src/utils/misc/app_export_import.dart` |
| Fork features | reader audio toolbar + `hiddenReaderToolbarItems` customise dialog, dual-language split view, per-book TTU settings, dictionary fonts, merged libraries + source pill, storage-cleanup schema v3, persistent search-worker isolate | `lib/**` |
| Agent config | `CLAUDE.md` and `.claude/skills/` stay tracked (upstream ignores them) | `.gitignore` |

⚠ **Never re-run `flutter_native_splash` from a merged config.** Regeneration writes upstream's art
back over the 白い熊 splash and produces no conflict while doing it.

Sweeps that must come back **empty**:

```bash
grep -rn "package:yuuna" lib/ vendor/ test/ 2>/dev/null
grep -rn "app\.arianneorpilla\.yuuna\|shiroikuma\.jidoujishodainihan\|jidoujisho2\|自動辞書第二版" \
  android/ lib/ pubspec.yaml
grep -n "^  isar:" pubspec.yaml            # must be isar_community
```

## Step 5 — regenerate, analyse, verify

```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH="$JAVA_HOME/bin:$HOME/git/flutter-3.44/bin:$PATH"

flutter pub get
dart run build_runner build --delete-conflicting-outputs   # isar_community + dart_mappable
dart run slang                                             # only if i18n JSONs changed
flutter analyze 2>&1 | tail -20
```

`flutter analyze` has pre-existing noise — compare the count against a pre-merge baseline
(`git stash` / a second checkout) rather than treating any output as a regression. Regenerated
`*.g.dart` and `lib/i18n/strings.g.dart` belong in the same commit as the merge resolution; history
already has "Final i18n regeneration" commits from the previous absorption.

## Step 6 — build the new `+NNN` and deliver

Follow the **build-and-release** skill (dev-build path). Standing authorization applies: build
without asking, once the gate has been passed.

```bash
pkill -f '[G]radleDaemon' || true          # bracketed [G] — a literal pattern kills this shell
set -o pipefail                            # a piped flutter build otherwise hides Gradle failure
new_ver=$(tools/bump-build.sh)             # zero-padded +NNN; never reuse a counter
apk_name="shiroikuma-jisho_${new_ver}_arm64-v8a.apk"
flutter clean                              # dependency graph moved — clean is warranted here
flutter build apk --split-per-abi --release
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$HOME/tmp/$apk_name"
sha1sum build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$HOME/tmp/$apk_name"
```

Verify the APK is actually fresh (the sha1 pair, and its mtime) before announcing it — a masked
Gradle failure otherwise ships the previous build under the new name. Then deliver via the global
**`/after-build`** flow (one target, first success wins: adb device → `192.168.1.73:5555` →
`skhw` → scp), and **`adb disconnect <ip>:5555` at the end of the batch**.

Then **stop and let 白い熊 test on-device.** No commit, no push, no `adb install`.

## Step 7 — changelog and the sync tag

Per the **changelog** skill, add `## [Unreleased]` entries for the user-visible parts of what was
absorbed, each ending with provenance in the established form:

```markdown
### Fixed

- Video player: YouTube playback no longer fails on age-gated videos
  (from upstream 2.10.0, 7f5d12fb).
```

Purely internal absorption (refactors, their CI, dependency churn with no observable effect) gets no
entry — say it in the commit body instead. If upstream fixed something we had already fixed
independently, do not list it twice; note the duplication in the commit body.

The landing commit body records: the tier used, upstream's version and tag, the commit range
absorbed, anything deliberately **not** taken and why, and — for Tier B — that per-commit history was
flattened.

## Step 8 — land and push ONLY after 白い熊 says "Push"

```bash
cd ~/git/shiroikuma-jisho
git checkout main
git merge --ff-only "upstream-merge-$new"
git push origin main

git tag "upstream-sync-$new" "upstream-$new"      # records the absorbed upstream commit
git push origin "upstream-sync-$new"
git branch -d "upstream-merge-$new"
```

`main` moves forward only — never force-push it. The `upstream-sync-<version>` tag is what the next
sync's `$base` reads, so never create it for commits that were not actually absorbed.

## One-line summary of the flow

`fetch upstream` → new version? (else report dormant and stop) → **⛔ tabular new-features report +
WAIT for proceed** → cut `upstream-merge-<version>` → absorb (Tier A merge with raised rename
limits / Tier B `-p2` patch / Tier C cherry-pick) → reconcile so every fork patch survives → pub get
+ codegen + analyse → build the new `+NNN` and deliver via `/after-build` → 白い熊 tests → on
**"Push"**: ff `main`, push, tag `upstream-sync-<version>`.

## Hard rules

- **The Step 2 proceed gate is mandatory.** Never create the integration branch, merge, apply, or
  build before 白い熊 says proceed. Standing request, 2026-08-17.
- **Never rebase `main` onto upstream, and never merge upstream straight onto `main`.** Absorption
  happens on `upstream-merge-<version>`; `main` only fast-forwards.
- **Never `git fetch upstream --tags --force`** — it would clobber our own release tags. Fetch new
  upstream tags as `refs/tags/upstream-<version>`. The `1.0.0` "would clobber existing tag" reject
  and the non-zero exit that comes with it are expected on every fetch; leave them alone.
- Never read "the newest local tag" as upstream's version; `v2.10.3` is ours.
- Never re-add `yuuna/` or `chisa/`; never enable a GitHub workflow (the one in `.github/` is
  disabled deliberately); never re-run `flutter_native_splash`; never follow
  upstream's ffmpeg-kit revert or its `2.x` version scheme.
- Never rename a `shiroikuma.jisho.action.PLAYBACK_*` action or break the export-bundle schema —
  both are frozen user-facing contracts.
- Never commit or push unprompted; wait for **"Push"**. Never `adb install` — 白い熊 installs from
  `/sdcard/tmp/` themselves; `adb disconnect` at the end of every delivery batch.
- Every `adb` invocation runs with `dangerouslyDisableSandbox: true`; so do `git push`, `gh`, `scp`,
  and writes under `~/git`. `$TMPDIR` is unset in an unsandboxed shell — pass an explicit scratch
  path. In a sandboxed shell never `git add -A` (phantom `/dev/null` masks appear as repo dotfiles) —
  stage paths explicitly.

---

**Commit convention — no Claude attribution.** Never add a `Co-Authored-By: Claude …` / "Generated
with Claude" trailer to commit messages or PR bodies; end the message at the last line of the body.
This overrides the harness default. (Global rule: `~/.claude/CLAUDE.md`.)

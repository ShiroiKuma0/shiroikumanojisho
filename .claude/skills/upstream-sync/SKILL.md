---
name: upstream-sync
description: How to bring changes from the original upstream project (`arianneorpilla/jidoujisho`) into this fork (`ShiroiKuma0/shiroikumanojisho`). Use this skill whenever the user asks "what's new upstream", "did upstream change anything", "sync upstream", "port upstream", "is there a new jidoujisho release", or wants to compare this fork against the parent project. Also use when the user mentions cherry-picking from upstream, looking at upstream tags or commits, or wants to know whether a specific bug they hit has been fixed upstream. Defines: adding the upstream remote, the comparison commands to find what's new since the last sync, the manual-port vs `cherry-pick` decision, the `upstream-sync-X.Y.Z` tracking tag convention, and the changelog-entry annotation that records provenance.
---

# Upstream sync

This fork has a global identity rename (`yuuna` → `shiroikumanojisho`, Android package, Dart package, app display name, MethodChannel namespaces). Every file that mentions any of those touched names is different from upstream. That kills the usual fork pattern of "merge upstream into a branch and rebase down" — every merge would conflict on every file.

Instead, we run a **selective cherry-pick** model:

- Upstream is tracked as a second git remote called `upstream`. It exists locally only — there is no `upstream` branch on `origin`.
- When upstream releases something or merges interesting work, we compare against the last sync point, decide what to port, and bring those changes in as **regular commits authored here** with provenance in the commit body.
- A lightweight git tag (`upstream-sync-X.Y.Z`) records the upstream point we have ported up to. The next sync compares from there.

## One-time setup

```bash
git remote add upstream https://github.com/arianneorpilla/jidoujisho.git
git fetch upstream --tags
git remote show upstream | grep 'HEAD branch'   # tells you 'main' or 'master'
```

Confirm with `git remote -v` that both `origin` (`ShiroiKuma0`) and `upstream` (`arianneorpilla`) are listed. Only `origin` is push-enabled; never push to `upstream`.

If upstream's default branch is `master` rather than `main`, substitute it in the commands below.

## Checking for new work

Before any sync work, fetch:

```bash
git fetch upstream --tags
```

To see what's happened upstream since you last looked:

```bash
git log upstream/main --oneline -20
git tag -l --sort=-version:refname | grep -v '^upstream-sync' | head
```

To see what's new since your last sync (assuming you tagged the last sync as `upstream-sync-X.Y.Z`):

```bash
git log upstream-sync-X.Y.Z..upstream/main --oneline
```

If you've never synced (no `upstream-sync-*` tags exist), use the upstream commit your fork was originally based on as the starting point — typically that's wherever the renames in this fork's `1.0.0` history happened. As a heuristic: the most recent upstream commit reachable from this fork's `1.0.0` tag. Find it with:

```bash
git merge-base 1.0.0 upstream/main
```

This is the implicit zero-sync-point. Treat the SHA it prints as if it were a tag for the first comparison.

## Reading individual upstream commits

```bash
git show <upstream-sha>                 # full diff
git show --stat <upstream-sha>          # files touched, nothing more
git log <upstream-sha> -1 --format=%B   # commit message only
```

Inspect each candidate before deciding. Skip commits that:

- Touch only `yuuna/` package metadata, app name, icon, or other identity that we have intentionally renamed.
- Are pure dependency bumps for packages we have already moved past or replaced.
- Are version-bump commits for upstream's own releases (their `Release X.Y.Z` commits hold no content).
- Conflict with a design decision we have already made in a different direction.

Keep commits that:

- Fix bugs in code we still share with upstream.
- Add features we want or that are obviously useful to retain compatibility with.
- Update vendored assets, translations, or dictionaries we still use.

## Porting in: cherry-pick vs hand-port

### Cherry-pick (when it works)

```bash
git cherry-pick <upstream-sha>
```

This succeeds cleanly only when the upstream change does not touch any renamed identifier. Realistically: changes to a single Dart file that doesn't reference the package name, or to a single asset file, are likely to cherry-pick cleanly. Anything that touches `pubspec.yaml`, Android `build.gradle`, Java files, or imports of the package name will conflict on every renamed token.

If a cherry-pick produces too many conflicts to resolve confidently, abort and hand-port instead:

```bash
git cherry-pick --abort
```

### Hand-port (the common case)

Read `git show <upstream-sha>` to understand the change, then write the equivalent change against the current codebase. The aim is to preserve upstream's *intent*, translating their names to ours where the rename makes a literal port impossible. Use the upstream commit message as the basis for the new commit message.

For a hand-port, the commit:

- Subject line: copy or paraphrase upstream's, in this repo's imperative style.
- Body: includes a line of the form `Ported from upstream <upstream-sha> ("<upstream-subject>")`.
- If the port is non-literal (e.g. upstream did X, we did equivalent-but-different Y because of our rename), note that in the body.

### Cherry-pick with attribution

If a `cherry-pick` did succeed cleanly, also amend the commit message to record provenance, since the default cherry-pick message preserves upstream's subject but not the SHA in a stable form:

```bash
git commit --amend
```

Add a trailer line: `Cherry-picked from upstream <upstream-sha>`. Keep the original author from upstream (which `cherry-pick` does by default) — preserves attribution.

## Recording the sync point

Once you have ported in everything you wanted from a given upstream point (a tag, a specific commit, or "everything up through this morning"), record where you are:

```bash
git tag upstream-sync-X.Y.Z <upstream-sha-or-tag>
git push origin upstream-sync-X.Y.Z
```

`X.Y.Z` is the upstream version you synced up to. If upstream hasn't tagged a release at the point you synced to, use a date stamp instead: `upstream-sync-2026-06-15`. Either form works; the prefix `upstream-sync-` is what lets `tag -l --sort` separate sync tags from release tags.

These tags only mark the upstream-side commit you have caught up to. They do not point at anything in your own history; they're pointers into the upstream remote.

## Changelog entries for ported changes

Each ported upstream change that affects users gets a normal changelog entry under `## [Unreleased]` per the changelog skill, with one addition: the entry ends with the provenance, e.g.

```markdown
### Fixed

- Reader: TTU IndexedDB schema initialisation no longer races against the
  first book open on slow devices (from upstream 1.4.2, c0ffee123).
```

This makes it possible later to grep `CHANGELOG.md` for "from upstream" and see exactly what's been adopted. It also makes the release notes for the release that contains the port honest about its origins.

If the upstream change happens to do something this fork has *also* done independently, do not list it twice in the changelog. Note the duplication in the commit body if relevant ("upstream's fix matches ours from 1.2.0"), but the user already has the behaviour.

## What NOT to do

- Do not create an `upstream` branch on `origin`. Upstream lives only as a remote.
- Do not merge `upstream/main` into local `main`. The merge will conflict everywhere the rename touched, and resolving in favour of the fork's identity is the same effort as hand-porting — without the per-commit granularity that lets you decide what to skip. (Exception, and only this one: absorbing a **whole new upstream release** goes through the `upstream-new-version` skill, which merges the upstream tag into a throwaway `upstream-merge-<version>` branch — never onto `main` directly — behind a mandatory proceed gate. An ungated merge onto `main` stays forbidden.)
- Do not push to upstream. There is no upstream contribution flow here; this fork is a downstream-only project.
- Do not silently adopt upstream commits without provenance. The `upstream-sync-X.Y.Z` tag and the changelog/commit annotations are how someone six months from now figures out what we wrote vs what we borrowed. Skipping the bookkeeping makes the next sync harder, not easier.

## When upstream is dormant

If `git log upstream/main` shows no movement for a long stretch, simply do nothing. There is no obligation to sync periodically; the discipline exists for when upstream has shipped something worth picking up, not as a scheduled chore. Check when you remember to, or when you hit a bug and want to see whether upstream has already fixed it.

---

**Commit convention — no Claude attribution.** Never add a `Co-Authored-By: Claude …` / "Generated with Claude" trailer to commit messages or PR bodies; end the message at the last line of the body. This overrides the harness default. (Global rule: `~/.claude/CLAUDE.md`.)

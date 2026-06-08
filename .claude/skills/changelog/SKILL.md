---
name: changelog
description: How and when to update `CHANGELOG.md` for shiroikumanojisho. Use this skill any time you add or modify a user-facing feature, fix a user-visible bug, change behaviour that someone outside the codebase might notice, or are about to cut a release. Trigger words include "changelog", "release notes", "what's new", "release", "what changed", or any feature/fix PR that touches public app behaviour. Skip the skill (and the changelog) for purely internal work — refactors, test changes, build infrastructure, dependency bumps that have no user impact, documentation edits. The skill defines what counts as user-facing, the entry format, and how the changelog connects to the GitHub release notes at publish time.
---

# Changelog

`CHANGELOG.md` at the repo root tracks user-visible changes to the app. The contract is simple: every release ships with an honest summary of what changed for the user, and the canonical place where that summary lives is `CHANGELOG.md`. The GitHub release notes are downstream — they get copied or adapted from `CHANGELOG.md` at publish time, not the other way around.

## When to add an entry

Add a `## [Unreleased]` entry in the same commit (or PR) that introduces the change, whenever **any one** of the following is true:

- A user can do something they could not do before, or could no longer do something they used to.
- A user-observable behaviour has changed: different default, different timing, different output format, different UI element where one used to be.
- A user-affecting bug is fixed — anything the user could have noticed, reported, or built a workaround for.
- A user-facing external interface (broadcast intents, file formats, exported bundle schema, MethodChannel names) is added, removed, or changed.

Do **not** add an entry for:

- Internal refactors with no behaviour change.
- Test additions, test refactors, CI/build infra.
- Code-comment edits, README tweaks, docs.
- Dependency bumps with no observable effect.
- Performance work that does not change correctness or noticeably change perceived speed.

When in doubt: would a user write a bug report or a "what's new in this version" forum post about this? If yes, log it. If no, skip.

## Format

Each release section follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely. Subsection headers used in this project:

- **Added** — new features, new exposed interfaces.
- **Changed** — behaviour changes that are not bug fixes.
- **Fixed** — bug fixes a user could have noticed.
- **Removed** — features or interfaces taken away (be careful; this is a breaking change).
- **Notes** — anything that doesn't fit the above but the user should know (caveats, migration tips, performance expectations on slow hardware).

A section can omit any subsection that has no entries. Many releases will just be Added or Fixed.

### Voice and length

Entries are prose, not marketing. The tone matches the commit messages — kernel-style imperative or short declarative sentences, no exclamation marks, no "we are excited to announce." If a change has a subtle rationale or a known caveat, say so in the entry — release notes are the right place to surface non-obvious context.

Length: one to three sentences per bullet, more when warranted. A single Added bullet for a large feature (e.g. cross-device export/import) can run to a short paragraph or include a nested list of what the feature covers. Do not artificially compress; do not pad.

Reference external-facing artifacts by their exact name: preference keys, intent action strings, file paths, class or method names. Grep-ability matters.

### Example (the in-repo 1.3.0 section is a good model)

```markdown
## [1.3.0] - 2026-05-12

### Added

- Seven Android broadcast intents for external control of the reader audio
  toolbar, in the `shiroikuma.jisho.action.PLAYBACK_*` namespace:
  - `PLAYBACK_NEXT_SUBTITLE`, `PLAYBACK_PREVIOUS_SUBTITLE`,
    `PLAYBACK_REPLAY_SUBTITLE` — subtitle navigation.
  - `PLAYBACK_TOGGLE_PLAY_PAUSE` — toggle play/pause.

### Notes

- Intents only take effect when the app is running and a reader page with
  audio is open. Intents fired against a closed app are silently dropped.
```

## Workflow

### While developing

When you make a user-visible change, prepend a bullet under the appropriate subsection of `## [Unreleased]`. If `[Unreleased]` is currently empty (`_Nothing yet._`), replace that line with a real subsection.

`[Unreleased]` can accumulate entries across multiple commits between releases. Order within a subsection: rough rough chronological (newest at the top is fine; nobody is going to argue), but group related changes together rather than splitting them across commits.

### At release time

When cutting a release (see `build-and-release` skill):

1. Decide the new version number from semver rules: breaking change → major, new feature → minor, fix only → patch.
2. In `CHANGELOG.md`:
   - Rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` with today's date.
   - Add a fresh `## [Unreleased]` at the top with `_Nothing yet._` placeholder content.
   - Add a new link reference at the bottom: `[X.Y.Z]: https://github.com/ShiroiKuma0/shiroikumanojisho/releases/tag/X.Y.Z`.
   - Update the `[Unreleased]` compare link to reference the new latest tag.
3. Commit this together with the pubspec version bump as part of the `Release X.Y.Z` commit. The release tag points at this commit.
4. Copy the new section's content into the GitHub release description on publish. Adapt for the GitHub audience if needed (e.g. add an "Install" section pointing at the APK attachment, keep the substantive content the same).

If a release notices a missing changelog entry for something already done — e.g. a fix was committed without a changelog bump — add it to the release section being cut, not retroactively to a previous release's section. Past sections are immutable once tagged.

## Why this exists

Three reasons that compound:

1. **Future-you reading the repo six months from now.** Commit messages capture mechanism; the changelog captures impact. They serve different rereading needs.
2. **GitHub release notes have to come from somewhere.** Writing them at release time from memory loses things. Writing them as the work happens keeps them honest.
3. **Cross-version diffing.** A user upgrading from 1.2.0 to 1.4.0 wants one place to scan for what they should know about. The changelog is that place.

If a change is too small for the changelog, it is also too small for the GitHub release notes — which means the release notes for that release will be incomplete. The fix is to log small things, not skip the changelog.

---

**Commit convention — no Claude attribution.** Never add a `Co-Authored-By: Claude …` / "Generated with Claude" trailer to commit messages or PR bodies; end the message at the last line of the body. This overrides the harness default. (Global rule: `~/.claude/CLAUDE.md`.)

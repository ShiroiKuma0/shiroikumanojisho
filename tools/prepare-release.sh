#!/usr/bin/env bash
# Prepare a release by bumping the app version and updating README
# links and history in one pass.
#
# Usage: tools/prepare-release.sh <new-version>
# Example: tools/prepare-release.sh 2.10.4
#
# The script:
#   - reads the current `version: X.Y.Z+N` line from pubspec.yaml
#   - sets it to `<new-version>+<N+1>`
#   - updates the two "latest release" links in README.md to point at
#     v<new-version>, and appends ` . <new-version>` to the history
#     list (which lives on a single line ending in `</b>`).
#
# The script deliberately does NOT commit, tag, or push — you review
# the diff first, then commit/tag/push yourself. It also refuses to
# run if the new version isn't strictly newer than the current one.

set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if [[ $# -ne 1 ]]; then
  die "usage: $0 <new-version>   (e.g. 2.10.4)"
fi

NEW_VER=$1
if ! [[ "$NEW_VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  die "version must be X.Y.Z, got '$NEW_VER'"
fi

# Resolve repo root from the script's location so the script works
# regardless of where it's invoked from.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PUBSPEC="$REPO_ROOT/pubspec.yaml"
README="$REPO_ROOT/README.md"

[[ -f "$PUBSPEC" ]] || die "pubspec not found: $PUBSPEC"
[[ -f "$README" ]] || die "README not found: $README"

# Extract current version and build number. The pubspec during
# development carries `X.Y.Z+N`; right before a release we
# overwrite it to plain `X.Y.Z` (no `+N`) — see NEW_FULL below.
CURRENT_LINE=$(grep -E '^version: [0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$' "$PUBSPEC" || true)
[[ -n "$CURRENT_LINE" ]] || die "could not find a 'version: X.Y.Z+N' line in $PUBSPEC"

CURRENT_VER=${CURRENT_LINE#version: }
CURRENT_SEMVER=${CURRENT_VER%+*}
CURRENT_BUILD=${CURRENT_VER##*+}

# Refuse to "bump" to the same or older version. Compare as tuples.
if [[ "$NEW_VER" == "$CURRENT_SEMVER" ]]; then
  die "new version ($NEW_VER) is the same as current ($CURRENT_SEMVER)"
fi
sort_check=$(printf '%s\n%s\n' "$CURRENT_SEMVER" "$NEW_VER" | sort -V | tail -n1)
if [[ "$sort_check" != "$NEW_VER" ]]; then
  die "new version ($NEW_VER) is older than current ($CURRENT_SEMVER)"
fi

# Release form is plain semver, no +N. bump-build.sh resumes dev
# iteration afterwards by appending +1, +2, ... on the next build.
NEW_FULL="$NEW_VER"

printf 'bumping %s → %s\n' "$CURRENT_VER" "$NEW_FULL"

# --- pubspec.yaml ---
# Use a precise match on the full current line so we never accidentally
# rewrite a similar-looking line elsewhere.
sed -i "s|^version: ${CURRENT_VER}\$|version: ${NEW_FULL}|" "$PUBSPEC"
grep -q "^version: ${NEW_FULL}\$" "$PUBSPEC" || die "pubspec rewrite failed"

# --- README.md ---
# Two edits. The README has two kinds of release references:
#
#  (1) Current-release links/labels: the release badge anchor near
#      the top and the visible "Latest Release: <VER>" paragraph
#      further down. These both point at the current release on
#      the active `shiroikumanojisho` repo and use tag names
#      WITHOUT a `v` prefix (user preference).
#
#  (2) History list: a multi-line series of `<a>` tags listing
#      every past release, grouped by era. The most recent era —
#      白い熊の辞書 — is the only one that gets appended to;
#      older eras (Legacy / Chisa / Yuuna / 白い熊の自動辞書第二版)
#      live on the archived `jidoujisho2` repo and are never
#      modified here.
#
# Neither the current-release label nor the appended history entry
# uses `v` in the tag name — it's plain `tag/X.Y.Z`.

# Safety check: the current version's link should appear somewhere.
grep -q "shiroikumanojisho/releases/tag/${CURRENT_SEMVER}" "$README" \
  || die "README doesn't mention shiroikumanojisho tag/${CURRENT_SEMVER} — already updated?"

# Rewrite badge + "Latest Release" references. These are the only
# shiroikumanojisho links that point at a specific tag on the main
# repo; updating them atomically via the substring
# `shiroikumanojisho/releases/tag/<CURRENT>` is both safe and
# complete.
sed -i "s|shiroikumanojisho/releases/tag/${CURRENT_SEMVER}|shiroikumanojisho/releases/tag/${NEW_VER}|g" "$README"
# Also update the visible label inside the "Latest Release" anchor.
# The badge anchor contains an <img> not a text label, so this
# touches only the visible-label paragraph.
sed -i "s|>${CURRENT_SEMVER}</a>|>${NEW_VER}</a>|g" "$README"

# Append the new version to the 白い熊の辞書 era history line.
# The history list is rendered as `<a>...</a> . <a>...</a></b>`
# with a trailing `</b>` marking the end of the current era. The
# last anchor inside that era closes the group. We find the final
# anchor in that era (which will now be the `>NEW_VER<` entry
# after the sweep above rewrote both label and URL) and insert a
# ` . <CURRENT>` entry before it, restoring the previous release
# into the history while keeping the new one as the latest.
python3 - "$README" "$CURRENT_SEMVER" "$NEW_VER" <<'PY'
import re
import sys

readme_path, current, new_ver = sys.argv[1], sys.argv[2], sys.argv[3]
with open(readme_path, encoding="utf-8") as f:
    text = f.read()

current_entry = (
    f'<a href="https://github.com/ShiroiKuma0/shiroikumanojisho'
    f'/releases/tag/{current}">{current}</a>'
)

# Find the final `<a ...tag/NEW">NEW</a>` in the 白い熊の辞書 era
# history line (identified by `shiroikumanojisho/releases/tag/`)
# and, if the `CURRENT` entry is gone, reinsert it immediately
# before the new one.
history_final_pattern = re.compile(
    r'(<a href="https://github\.com/ShiroiKuma0/shiroikumanojisho'
    r'/releases/tag/' + re.escape(new_ver) + r'">' +
    re.escape(new_ver) + r'</a>)'
)
if f'shiroikumanojisho/releases/tag/{current}' not in text:
    def repl(m):
        return f'{current_entry} .\n  {m.group(1)}'
    text, n = history_final_pattern.subn(repl, text, count=1)
    if n != 1:
        sys.exit('error: could not restore current-version history entry')

with open(readme_path, 'w', encoding="utf-8") as f:
    f.write(text)
PY

printf '\ndiff:\n'
git -C "$REPO_ROOT" diff -- "$PUBSPEC" "$README" | head -80

printf '\nNext steps:\n'
printf '  1. Review the diff above (run `git diff` for the full view).\n'
printf '  2. Build and install to verify everything still works.\n'
printf '  3. git add -A && git commit -m "Release %s" && git tag -a %s -m "Release %s" && git push origin main && git push origin %s\n' \
  "$NEW_VER" "$NEW_VER" "$NEW_VER" "$NEW_VER"

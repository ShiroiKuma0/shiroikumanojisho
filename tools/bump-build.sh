#!/usr/bin/env bash
# Bump the build number (+N) in pubspec.yaml by one.
#
# Usage: tools/bump-build.sh
#
# Accepts two pubspec version forms:
#   X.Y.Z+N  -> rewrites to X.Y.Z+(N+1)
#   X.Y.Z    -> rewrites to X.Y.Z+1  (first dev build after a release)
#
# Prints the new full version string to stdout for easy capture in
# shell blocks via new_ver=$(tools/bump-build.sh).
#
# Used by the dev build flow so every dev APK gets a fresh build
# number, which then surfaces in the app's title bar (via
# PackageInfo.buildNumber) so the user can tell at-a-glance which
# dev iteration they are running.
#
# Release prep does NOT use this script -- prepare-release.sh
# handles that case, setting the target semver and resetting the
# build number as appropriate.

set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PUBSPEC="$REPO_ROOT/pubspec.yaml"

[[ -f "$PUBSPEC" ]] || die "pubspec not found: $PUBSPEC"

# Accept either X.Y.Z or X.Y.Z+N.
CURRENT_LINE=$(grep -E '^version: [0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$' "$PUBSPEC" || true)
[[ -n "$CURRENT_LINE" ]] || die "pubspec version must match X.Y.Z or X.Y.Z+N, got: $(grep '^version:' "$PUBSPEC" || echo '<none>')"

CURRENT_VER=${CURRENT_LINE#version: }
if [[ "$CURRENT_VER" == *+* ]]; then
    CURRENT_SEMVER=${CURRENT_VER%+*}
    CURRENT_BUILD=${CURRENT_VER##*+}
else
    # Release form: treat implicit build as 0 so the first dev
    # iteration after the release lands on X.Y.Z+1.
    CURRENT_SEMVER=$CURRENT_VER
    CURRENT_BUILD=0
fi
NEW_BUILD=$((CURRENT_BUILD + 1))
NEW_FULL="$CURRENT_SEMVER+$NEW_BUILD"

# Precise match on the full current line so nothing similar-looking
# elsewhere in the file gets rewritten.
sed -i "s|^version: ${CURRENT_VER}\$|version: ${NEW_FULL}|" "$PUBSPEC"
grep -q "^version: ${NEW_FULL}\$" "$PUBSPEC" || die "pubspec rewrite failed"

printf '%s\n' "$NEW_FULL"

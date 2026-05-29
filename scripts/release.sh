#!/usr/bin/env bash
# Cut a new release: bump the version, sync it into every import + the README,
# smoke-test the new source against a @local install, lint, then commit + tag.
#
#   scripts/release.sh 0.1.2
#
# Then push to trigger the Universe-PR workflow:
#
#   git push --follow-tags
#
# Published Universe versions are immutable, so a release is always a fresh,
# strictly-greater version — never a re-run of an existing one.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/setup

# version_gt <a> <b>: succeeds iff version a > b (both X.Y.Z, already validated).
# Pure bash so it needs no GNU `sort -V` (BSD/macOS sort lacks -V). 10# forces
# base-10 so a zero-padded field like 08 isn't read as octal.
version_gt() {
  local IFS=.
  local -a a=($1) b=($2)
  local i
  for i in 0 1 2; do
    if (( 10#${a[i]} > 10#${b[i]} )); then return 0; fi
    if (( 10#${a[i]} < 10#${b[i]} )); then return 1; fi
  done
  return 1
}

new="${1:?usage: scripts/release.sh <new-version>  e.g. 0.1.2}"
old="$VERSION"

# --- validate -------------------------------------------------------------
[[ "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: version must be X.Y.Z" >&2; exit 1; }
[[ "$new" != "$old" ]] || { echo "error: $new is already the current version" >&2; exit 1; }
if ! version_gt "$new" "$old"; then
  echo "error: $new is not greater than current $old (published versions are immutable)" >&2
  exit 1
fi
[[ -z "$(git status --porcelain)" ]] || { echo "error: working tree is dirty; commit or stash first" >&2; exit 1; }

echo ">> releasing $old -> $new"

# --- 1. manifest ----------------------------------------------------------
"${SED_INPLACE[@]}" "s/^version = \"$old\"/version = \"$new\"/" typst.toml

# --- 2. sync every aero-dhbw import to @preview:<new> ---------------------
# Normalises the namespace to @preview (in case a @local import was left behind
# from local testing) AND bumps the version, across templates + README. This is
# the duplication that Universe forces on us: templates must use absolute
# @preview imports, so the version is hard-coded in several files.
{ grep -rlE '@(preview|local)/aero-dhbw:[0-9]+\.[0-9]+\.[0-9]+' template README.md 2>/dev/null || true; } | while IFS= read -r f; do
  "${SED_INPLACE[@]}" -E "s#@(preview|local)/aero-dhbw:[0-9]+\.[0-9]+\.[0-9]+#@preview/aero-dhbw:$new#g" "$f"
  echo "   synced $f"
done

# --- 3. smoke-test: template compiles against a @local install of the new source ---
echo ">> smoke-testing the new source"
scripts/test

# --- 4. lint (optional, mirrors upstream CI) ------------------------------
if command -v typst-package-check >/dev/null 2>&1; then
  echo ">> typst-package-check"
  typst-package-check
else
  echo ">> typst-package-check not installed locally — skipping (upstream CI runs it)"
fi

# --- 5. commit + tag ------------------------------------------------------
git add typst.toml template README.md
git commit -m "chore: release v$new"
# Annotated (not lightweight) so `git push --follow-tags` actually pushes it.
git tag -a "v$new" -m "aero-dhbw v$new"

echo
echo "Released v$new locally. Review the commit, then publish with:"
echo "    git push --follow-tags"

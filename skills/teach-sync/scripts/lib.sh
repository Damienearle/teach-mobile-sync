#!/usr/bin/env bash
#
# lib.sh — shared constants and helpers for teach-sync's check.sh and apply.sh.
# Sourced only; not meant to be executed directly.

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}==>${NC} $1" >&2; }
warn()  { echo -e "${YELLOW}!!${NC} $1" >&2; }
err()   { echo -e "${RED}xx${NC} $1" >&2; }

# Gitignore patterns that would hide /teach skill or progress files from git.
RISKY_GITIGNORE_PATTERNS=(".claude" ".agents" "lessons" "learning-records" "MISSION.md" "RESOURCES.md")

# Files/dirs expected in a fully set-up /teach project.
EXPECTED_TEACH_ARTIFACTS=("MISSION.md" "RESOURCES.md" "lessons" "learning-records")

# Searches common locations for an installed /teach skill: both under the
# given project directory (a per-project install) and under the user's home
# directory (a global install, e.g. `npx skills add ... -g`) — teach-sync
# itself recommends installing globally, so /teach is often global too, not
# sitting inside the project folder at all. Prints matching paths (one per
# line) to stdout; prints nothing and returns 1 if none found. Globs alone
# are used (not also the exact ".../teach" path) since "*teach*" already
# matches a directory named exactly "teach" — listing both would report the
# same match twice. Explicitly skips "teach-sync" itself: it's this skill's
# own name, so it's almost always installed alongside /teach (globally,
# project-locally, or mirrored under .agents/skills/ by the CLI's "universal"
# install mode) and would otherwise self-match as a false positive.
find_teach_skill() {
  local dir="$1"
  local found=0
  local d base
  for d in "$dir"/.claude/skills/*teach* "$dir"/.agents/skills/*teach* \
           "$HOME"/.claude/skills/*teach* "$HOME"/.agents/skills/*teach*; do
    if [[ -d "$d" ]]; then
      base="$(basename "$d")"
      [[ "$base" == "teach-sync" ]] && continue
      echo "$d"
      found=1
    fi
  done
  [[ "$found" -eq 1 ]]
}

# Escapes a literal string for safe interpolation into a grep -E/sed
# pattern, so a "." in a filename (e.g. "MISSION.md") is matched literally
# instead of as "any character". Pure bash string substitution rather than a
# sed-based escape, to sidestep BRE/ERE bracket-expression edge cases.
escape_regex() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//./\\.}"
  s="${s//\*/\\*}"
  s="${s//\[/\\[}"
  s="${s//\]/\\]}"
  s="${s//^/\\^}"
  s="${s//\$/\\$}"
  printf '%s' "$s"
}

# Prints (comma-free, one per line) which RISKY_GITIGNORE_PATTERNS entries
# are present as exact ignore lines in <dir>/.gitignore. Text-pattern based
# rather than `git check-ignore`-based deliberately: it must give a correct
# answer even before `git init` has run (check.sh calls this during
# preflight, ahead of any git state), and it must agree exactly with what
# apply.sh's gitignore stage will actually strip.
gitignore_flagged_patterns() {
  local dir="$1"
  local gitignore="$dir/.gitignore"
  [[ -f "$gitignore" ]] || return 0
  local p escaped
  for p in "${RISKY_GITIGNORE_PATTERNS[@]}"; do
    escaped="$(escape_regex "$p")"
    if grep -Eq "^${escaped}(/)?\$" "$gitignore" 2>/dev/null; then
      echo "$p"
    fi
  done
}

# Turns a directory name into a reasonable GitHub repo name: lowercase,
# spaces/underscores to hyphens, strip anything outside [a-z0-9-], collapse
# repeated hyphens, trim leading/trailing hyphens. Uses tr/sed rather than
# bash 4's ${var,,} since macOS ships bash 3.2.
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' \
    | sed -E 's/[^a-z0-9-]+//g; s/-+/-/g; s/^-+//; s/-+$//'
}

# Resolves the gh CLI binary to invoke: prefers a bare "gh" already on PATH
# (the common case), but falls back to checking common absolute install
# locations across platforms if that fails. This matters because installing
# gh (e.g. via winget, right after this skill suggested it) updates the
# *system* PATH, not the environment already inherited by whatever shell is
# running this session — so `command -v gh` keeps failing until that shell
# is restarted, even though gh is genuinely there. Prints the resolved
# binary (bare "gh" or an absolute path) to stdout; prints nothing and
# returns 1 if gh can't be found anywhere.
find_gh_bin() {
  if command -v gh >/dev/null 2>&1; then
    printf 'gh'
    return 0
  fi
  local candidates=(
    "/c/Program Files/GitHub CLI/gh.exe"
    "/opt/homebrew/bin/gh"
    "/usr/local/bin/gh"
    "/usr/bin/gh"
    "$HOME/.local/bin/gh"
  )
  [[ -n "${LOCALAPPDATA:-}" ]] && candidates+=("$LOCALAPPDATA/Microsoft/WinGet/Links/gh.exe")
  local c
  for c in "${candidates[@]}"; do
    [[ -x "$c" ]] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

# Extracts the topic from <dir>/MISSION.md's "# Mission: {Topic}" heading —
# the format /teach's own MISSION-FORMAT.md prescribes. Prints the trimmed
# topic text to stdout; prints nothing and returns 1 if MISSION.md doesn't
# exist yet (a brand-new topic /teach hasn't run on) or doesn't match the
# expected heading. Lets check.sh prefer a real topic name over the folder's
# name for the suggested repo name once one exists.
extract_mission_topic() {
  local mission_file="$1/MISSION.md"
  [[ -f "$mission_file" ]] || return 1
  local line topic
  line="$(grep -m1 -E '^# Mission:' "$mission_file" 2>/dev/null)"
  [[ -n "$line" ]] || return 1
  topic="${line#*Mission:}"
  topic="$(echo "$topic" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [[ -n "$topic" ]] || return 1
  printf '%s' "$topic"
}

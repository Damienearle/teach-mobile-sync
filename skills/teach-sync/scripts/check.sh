#!/usr/bin/env bash
#
# check.sh --dir PATH
#
# Read-only preflight for teach-sync. Never mutates anything — safe to
# re-run at any point. Prints plain KEY=value facts (one per line, stdout)
# describing the target directory's git/teach-skill/gitignore state, for
# the calling skill to parse and reason about.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

TARGET_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) TARGET_DIR="$2"; shift 2 ;;
    *) err "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$TARGET_DIR" ]]; then
  err "--dir is required"
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "TARGET_DIR_EXISTS=no"
  exit 0
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
cd "$TARGET_DIR" || exit 1

echo "TARGET_DIR=$TARGET_DIR"
echo "TARGET_DIR_EXISTS=yes"

# ---------------------------------------------------------------------------
# Repo name suggestion — prefers the real /teach topic over the folder name
# once one exists (MISSION.md's "# Mission: {Topic}" heading), since a
# brand-new topic folder's name is often just a placeholder picked before
# /teach's own topic conversation happened.
# ---------------------------------------------------------------------------

if MISSION_TOPIC="$(extract_mission_topic "$TARGET_DIR")"; then
  echo "MISSION_TOPIC=$MISSION_TOPIC"
  echo "SUGGESTED_REPO_NAME=$(slugify "$MISSION_TOPIC")"
  echo "REPO_NAME_SOURCE=mission_topic"
else
  echo "MISSION_TOPIC="
  echo "SUGGESTED_REPO_NAME=$(slugify "$(basename "$TARGET_DIR")")"
  echo "REPO_NAME_SOURCE=folder_name"
fi

# ---------------------------------------------------------------------------
# Git repo state
# ---------------------------------------------------------------------------

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "GIT_REPO=yes"

  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "HAS_COMMITS=yes"
  else
    echo "HAS_COMMITS=no"
  fi

  BRANCH="$(git branch --show-current 2>/dev/null)"
  echo "CURRENT_BRANCH=${BRANCH:-none}"

  if REMOTE_URL="$(git remote get-url origin 2>/dev/null)"; then
    echo "REMOTE_ORIGIN=$REMOTE_URL"
  else
    echo "REMOTE_ORIGIN=none"
  fi
else
  echo "GIT_REPO=no"
  echo "HAS_COMMITS=no"
  echo "CURRENT_BRANCH=none"
  echo "REMOTE_ORIGIN=none"
fi

# ---------------------------------------------------------------------------
# /teach skill detection
# ---------------------------------------------------------------------------

TEACH_PATHS_LIST=()
while IFS= read -r line; do
  [[ -n "$line" ]] && TEACH_PATHS_LIST+=("$line")
done < <(find_teach_skill "$TARGET_DIR" 2>/dev/null || true)

if [[ ${#TEACH_PATHS_LIST[@]} -gt 0 ]]; then
  echo "TEACH_SKILL_FOUND=yes"
  IFS=,; echo "TEACH_SKILL_PATHS=${TEACH_PATHS_LIST[*]}"; unset IFS
else
  echo "TEACH_SKILL_FOUND=no"
  echo "TEACH_SKILL_PATHS="
fi

# ---------------------------------------------------------------------------
# Expected /teach artifacts
# ---------------------------------------------------------------------------

MISSING=()
for f in "${EXPECTED_TEACH_ARTIFACTS[@]}"; do
  [[ -e "$f" ]] || MISSING+=("$f")
done
IFS=,; echo "TEACH_ARTIFACTS_MISSING=${MISSING[*]}"; unset IFS

# ---------------------------------------------------------------------------
# Gitignore risk — text-pattern based (see lib.sh:gitignore_flagged_patterns)
# so this gives a correct answer even before `git init` has run, and always
# agrees with what apply.sh's gitignore stage will actually strip.
# ---------------------------------------------------------------------------

RISKY=()
while IFS= read -r line; do
  [[ -n "$line" ]] && RISKY+=("$line")
done < <(gitignore_flagged_patterns "$TARGET_DIR")
IFS=,; echo "GITIGNORE_RISKY=${RISKY[*]}"; unset IFS

# ---------------------------------------------------------------------------
# .agents / .claude symlink check
# ---------------------------------------------------------------------------

if [[ -L .agents && -d .claude ]]; then
  AGENTS_IS_RISKY=0
  for p in "${RISKY[@]}"; do
    [[ "$p" == ".agents" ]] && AGENTS_IS_RISKY=1
  done
  if [[ "$AGENTS_IS_RISKY" -eq 1 ]]; then
    echo "AGENTS_SYMLINK=ignored"
  else
    echo "AGENTS_SYMLINK=trackable"
  fi
elif [[ -e .agents ]]; then
  echo "AGENTS_SYMLINK=not_a_symlink"
else
  echo "AGENTS_SYMLINK=none"
fi

# ---------------------------------------------------------------------------
# Tooling availability
# ---------------------------------------------------------------------------

if command -v gh >/dev/null 2>&1; then
  echo "GH_CLI=yes"
  if gh auth status >/dev/null 2>&1; then
    echo "GH_AUTHENTICATED=yes"
  else
    echo "GH_AUTHENTICATED=no"
  fi
else
  echo "GH_CLI=no"
  echo "GH_AUTHENTICATED=no"
fi
if command -v npx >/dev/null 2>&1; then echo "NPX_AVAILABLE=yes"; else echo "NPX_AVAILABLE=no"; fi

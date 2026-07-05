#!/usr/bin/env bash
#
# smoke-test.sh
#
# Exercises check.sh and apply.sh end-to-end against a scratch directory and
# a local bare repo standing in for GitHub, automating the manual
# verification steps described in this repo's CLAUDE.md. Run locally or in
# CI (see .github/workflows/test.yml); exits non-zero on the first failed
# assertion.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PROJECT="$WORK/my-topic"
REMOTE="$WORK/remote.git"

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "ok - $1"; }

# kv OUTPUT KEY — extracts KEY=value from a captured check.sh stdout blob.
kv() {
  printf '%s\n' "$1" | sed -n "s/^${2}=//p"
}

# --- brand-new, empty topic folder ------------------------------------------

mkdir -p "$PROJECT"
OUT="$(bash "$SCRIPT_DIR/check.sh" --dir "$PROJECT")"
[[ "$(kv "$OUT" TARGET_DIR_EXISTS)" == "yes" ]] || fail "expected TARGET_DIR_EXISTS=yes"
[[ "$(kv "$OUT" GIT_REPO)" == "no" ]] || fail "expected GIT_REPO=no on a fresh folder"
pass "check.sh reports a fresh folder correctly"

# --- /teach skill detection avoids self-matching teach-sync ------------------

mkdir -p "$PROJECT/.claude/skills/teach-sync"
OUT="$(bash "$SCRIPT_DIR/check.sh" --dir "$PROJECT")"
[[ "$(kv "$OUT" TEACH_SKILL_FOUND)" == "no" ]] \
  || fail "expected TEACH_SKILL_FOUND=no when only teach-sync itself is installed"
pass "check.sh does not mistake teach-sync for /teach itself"

mkdir -p "$PROJECT/.claude/skills/teach"
OUT="$(bash "$SCRIPT_DIR/check.sh" --dir "$PROJECT")"
[[ "$(kv "$OUT" TEACH_SKILL_FOUND)" == "yes" ]] \
  || fail "expected TEACH_SKILL_FOUND=yes once /teach itself is installed"
pass "check.sh detects an actual /teach install"

rm -rf "$PROJECT/.claude"

# --- repo name suggestion: folder name vs. mission topic --------------------

OUT="$(bash "$SCRIPT_DIR/check.sh" --dir "$PROJECT")"
[[ "$(kv "$OUT" REPO_NAME_SOURCE)" == "folder_name" ]] \
  || fail "expected REPO_NAME_SOURCE=folder_name before MISSION.md exists"
[[ "$(kv "$OUT" SUGGESTED_REPO_NAME)" == "my-topic" ]] \
  || fail "expected SUGGESTED_REPO_NAME derived from the folder name"
pass "check.sh suggests a folder-derived repo name before /teach has run"

cat > "$PROJECT/MISSION.md" <<'EOF'
# Mission: Learn Rust Basics

## Why
Ship a small CLI tool.
EOF
OUT="$(bash "$SCRIPT_DIR/check.sh" --dir "$PROJECT")"
[[ "$(kv "$OUT" REPO_NAME_SOURCE)" == "mission_topic" ]] \
  || fail "expected REPO_NAME_SOURCE=mission_topic once MISSION.md exists"
[[ "$(kv "$OUT" MISSION_TOPIC)" == "Learn Rust Basics" ]] \
  || fail "expected MISSION_TOPIC to be parsed from the heading, got: $(kv "$OUT" MISSION_TOPIC)"
[[ "$(kv "$OUT" SUGGESTED_REPO_NAME)" == "learn-rust-basics" ]] \
  || fail "expected SUGGESTED_REPO_NAME derived from the mission topic, got: $(kv "$OUT" SUGGESTED_REPO_NAME)"
pass "check.sh prefers the mission topic over the folder name once /teach has run"

rm -f "$PROJECT/MISSION.md"

bash "$SCRIPT_DIR/apply.sh" --dir "$PROJECT" --stage init || fail "init stage failed"
[[ -d "$PROJECT/.git" ]] || fail "expected .git after init stage"
pass "init stage creates a git repo"

bash "$SCRIPT_DIR/apply.sh" --dir "$PROJECT" --stage commit
CODE=$?
[[ "$CODE" -eq 3 ]] || fail "expected exit 3 committing an empty folder, got $CODE"
pass "commit stage exits 3 on a still-empty folder"

# --- gitignore risk detection ------------------------------------------------

cat > "$PROJECT/.gitignore" <<'EOF'
learning-records
MISSION.md
EOF
OUT="$(bash "$SCRIPT_DIR/check.sh" --dir "$PROJECT")"
RISKY="$(kv "$OUT" GITIGNORE_RISKY)"
[[ "$RISKY" == *"learning-records"* && "$RISKY" == *"MISSION.md"* ]] \
  || fail "expected both risky patterns flagged, got: $RISKY"
pass "check.sh flags risky .gitignore patterns"

bash "$SCRIPT_DIR/apply.sh" --dir "$PROJECT" --stage gitignore --fix-gitignore \
  || fail "gitignore stage failed"
grep -q "learning-records" "$PROJECT/.gitignore" \
  && fail "expected learning-records removed from .gitignore"
grep -q "^MISSION.md\$" "$PROJECT/.gitignore" \
  && fail "expected MISSION.md removed from .gitignore"
pass "gitignore --fix-gitignore strips risky lines"

# --- real content, first commit ---------------------------------------------

echo "# My Topic" > "$PROJECT/MISSION.md"
mkdir -p "$PROJECT/learning-records"
touch "$PROJECT/learning-records/.gitkeep"

bash "$SCRIPT_DIR/apply.sh" --dir "$PROJECT" --stage commit --commit-message-stdin <<<"sync /teach progress"
CODE=$?
[[ "$CODE" -eq 0 ]] || fail "expected exit 0 committing real content, got $CODE"
pass "commit stage succeeds once there's real content"

# --- remote + push, against a local bare repo standing in for GitHub -------

git init --bare -b main "$REMOTE" >/dev/null
bash "$SCRIPT_DIR/apply.sh" --dir "$PROJECT" --stage remote --remote-url "$REMOTE" \
  || fail "remote stage failed"
bash "$SCRIPT_DIR/apply.sh" --dir "$PROJECT" --stage push \
  || fail "push stage failed"

git --git-dir="$REMOTE" log -1 --format=%s 2>/dev/null | grep -q "sync /teach progress" \
  || fail "expected the commit to have reached the bare remote"
pass "remote + push land the commit in the fake GitHub remote"

echo "All smoke tests passed."

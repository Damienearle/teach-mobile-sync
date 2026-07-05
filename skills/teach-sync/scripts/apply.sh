#!/usr/bin/env bash
#
# apply.sh --dir PATH --stage all|init|gitignore|commit|remote|push [flags]
#
# Mechanical, non-interactive git/gh actions for teach-sync. Never prompts —
# every decision must already be made by the caller and passed as a flag.
# Staged and idempotent: each stage can be re-run safely, and a later stage
# can be re-invoked alone after an earlier one already succeeded.
#
# Flags:
#   --dir PATH               required
#   --stage STAGE             required; one of: all, init, gitignore, commit, remote, push
#   --fix-gitignore           (gitignore stage) actually strip risky lines; otherwise a no-op
#   --commit-message-stdin    (commit stage) read the commit message from stdin instead of
#                             using the default "sync /teach progress"
#   --gh-create-repo NAME     (remote stage) create a private repo via gh and push
#   --gh-bin PATH             (remote stage) gh binary to invoke; defaults to "gh" (PATH
#                             lookup). Pass check.sh's GH_BIN when it resolved gh via an
#                             absolute-path fallback (e.g. gh was just installed and isn't
#                             on this shell's PATH yet) so this still works without a
#                             terminal restart.
#   --remote-url URL          (remote stage) add an existing repo URL as origin
#                             (--gh-create-repo and --remote-url are mutually exclusive;
#                             there is no --public flag, intentionally — this tool never
#                             creates a public repo)
#   --branch NAME             (push stage) branch to push; defaults to the current branch
#
# Exit codes:
#   0  success
#   1  usage / precondition error
#   3  (commit stage only) no commits exist anywhere in this repo's history —
#      i.e. this is a brand-new, still-empty /teach topic. The caller should
#      stop here and point the user at /teach rather than attempting remote/push.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

TARGET_DIR=""
STAGE=""
FIX_GITIGNORE=0
COMMIT_MESSAGE_STDIN=0
GH_CREATE_REPO=""
GH_BIN="gh"
REMOTE_URL_ARG=""
BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) TARGET_DIR="$2"; shift 2 ;;
    --stage) STAGE="$2"; shift 2 ;;
    --fix-gitignore) FIX_GITIGNORE=1; shift ;;
    --commit-message-stdin) COMMIT_MESSAGE_STDIN=1; shift ;;
    --gh-create-repo) GH_CREATE_REPO="$2"; shift 2 ;;
    --gh-bin) GH_BIN="$2"; shift 2 ;;
    --remote-url) REMOTE_URL_ARG="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    *) err "Unknown argument: $1"; exit 1 ;;
  esac
done

[[ -z "$TARGET_DIR" ]] && { err "--dir is required"; exit 1; }
[[ -z "$STAGE" ]] && { err "--stage is required"; exit 1; }
[[ -n "$GH_CREATE_REPO" && -n "$REMOTE_URL_ARG" ]] && { err "--gh-create-repo and --remote-url are mutually exclusive"; exit 1; }
[[ ! -d "$TARGET_DIR" ]] && { err "Directory does not exist: $TARGET_DIR"; exit 1; }

cd "$TARGET_DIR" || exit 1

stage_init() {
  if [[ ! -d .git ]]; then
    if ! git init -b main; then
      err "git init failed."
      exit 1
    fi
    info "Initialized git repo."
  else
    info "Existing git repo found."
  fi
}

stage_gitignore() {
  if [[ "$FIX_GITIGNORE" -ne 1 ]]; then
    info "Gitignore fix not requested — skipping."
    return 0
  fi
  if [[ ! -f .gitignore ]]; then
    info "No .gitignore present — nothing to fix."
    return 0
  fi
  local flagged=()
  local p
  while IFS= read -r p; do
    [[ -n "$p" ]] && flagged+=("$p")
  done < <(gitignore_flagged_patterns "$(pwd)")
  if [[ ${#flagged[@]} -eq 0 ]]; then
    info ".gitignore has no risky patterns to remove."
    return 0
  fi
  local escaped
  for p in "${flagged[@]}"; do
    escaped="$(escape_regex "$p")"
    if ! sed -i.bak "/^${escaped}\/*\$/d" .gitignore; then
      err "Failed to update .gitignore."
      rm -f .gitignore.bak
      exit 1
    fi
  done
  rm -f .gitignore.bak
  info "Removed from .gitignore: ${flagged[*]}"
}

stage_commit() {
  if ! git add -A; then
    err "git add failed."
    exit 1
  fi

  local f
  for f in "${EXPECTED_TEACH_ARTIFACTS[@]}" .claude .agents; do
    if [[ -e "$f" ]]; then
      if git ls-files --error-unmatch "$f" >/dev/null 2>&1 || git ls-files -- "$f" | grep -q .; then
        info "$f is tracked."
      else
        warn "$f exists locally but is NOT tracked by git."
      fi
    fi
  done

  local msg=""
  if [[ "$COMMIT_MESSAGE_STDIN" -eq 1 ]]; then
    msg="$(cat)"
  fi
  msg="${msg:-sync /teach progress}"

  if git diff --cached --quiet; then
    info "Nothing new to commit."
  else
    if ! git commit -m "$msg"; then
      err "git commit failed."
      exit 1
    fi
    info "Committed."
  fi

  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    warn "No commits exist yet — this topic folder is still empty."
    exit 3
  fi
}

stage_remote() {
  if git remote get-url origin >/dev/null 2>&1; then
    info "Remote 'origin' already set: $(git remote get-url origin)"
    return 0
  fi
  if [[ -n "$GH_CREATE_REPO" ]]; then
    if ! "$GH_BIN" repo create "$GH_CREATE_REPO" --private --source=. --remote=origin --push; then
      err "gh repo create failed — the name may already be taken, gh's auth may have expired, or there's a network issue. Try a different name, or fall back to --remote-url with a manually created repo."
      exit 1
    fi
    info "Private repo created and pushed via gh."
  elif [[ -n "$REMOTE_URL_ARG" ]]; then
    if ! git remote add origin "$REMOTE_URL_ARG"; then
      err "git remote add failed."
      exit 1
    fi
    info "Remote added: $REMOTE_URL_ARG"
  else
    err "remote stage requires --gh-create-repo or --remote-url"
    exit 1
  fi
}

stage_push() {
  if ! git remote get-url origin >/dev/null 2>&1; then
    err "No remote 'origin' configured — run the remote stage first."
    exit 1
  fi
  local branch="${BRANCH:-$(git branch --show-current)}"
  info "Pushing '$branch' to origin..."
  if ! git push -u origin "$branch"; then
    err "git push failed — the remote may already have commits that diverge from this local history (e.g. it was created with a README), or credentials may be missing/expired. Resolve the underlying issue (e.g. 'git pull --rebase origin $branch' if histories diverged) and re-run the push stage."
    exit 1
  fi
  info "Pushed."
}

case "$STAGE" in
  init) stage_init ;;
  gitignore) stage_gitignore ;;
  commit) stage_commit ;;
  remote) stage_remote ;;
  push) stage_push ;;
  all)
    stage_init
    stage_gitignore
    stage_commit
    stage_remote
    stage_push
    ;;
  *) err "Unknown stage: $STAGE"; exit 1 ;;
esac

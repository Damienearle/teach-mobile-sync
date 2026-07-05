#!/usr/bin/env bash
#
# setup-teach-sync.sh
#
# Automates getting a /teach skill project into a GitHub repo so it can be
# opened in a Claude Code cloud session (claude.ai/code or the Android app)
# without your laptop needing to be on.
#
# Run this from the root of your /teach project (the folder that contains
# MISSION.md, RESOURCES.md, lessons/, learning-records/, and the .claude or
# .agents skill folder).

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}==>${NC} $1"; }
warn()  { echo -e "${YELLOW}!!${NC} $1"; }
err()   { echo -e "${RED}xx${NC} $1"; }
ask()   { read -rp "$(echo -e "${BOLD}$1${NC} ")" REPLY; echo "$REPLY"; }

# ---------------------------------------------------------------------------
# 0. Sanity checks
# ---------------------------------------------------------------------------

command -v git >/dev/null 2>&1 || { err "git is not installed. Install it first."; exit 1; }

echo -e "${BOLD}/teach sync setup${NC}"
echo "This will turn the current directory into a git repo (if it isn't one),"
echo "verify your skill files will actually be tracked, and push it to GitHub"
echo "so you can open it in a Claude Code cloud session from your phone."
echo

CONFIRM=$(ask "Is this directory your /teach project root? [y/N]:")
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  err "cd into your /teach project folder and re-run this script."
  exit 1
fi

# ---------------------------------------------------------------------------
# 0b. Check if the /teach skill itself is installed, offer to install it
# ---------------------------------------------------------------------------

TEACH_FOUND=0
for d in .claude/skills/teach .agents/skills/teach .claude/skills/*teach* .agents/skills/*teach*; do
  if [[ -d "$d" ]]; then
    TEACH_FOUND=1
    break
  fi
done

if [[ "$TEACH_FOUND" -eq 0 ]]; then
  warn "Couldn't find an installed /teach skill in .claude/skills or .agents/skills."
  command -v npx >/dev/null 2>&1 || { err "npx (Node.js) is not installed — install Node from nodejs.org first, then re-run."; exit 1; }
  INSTALL_NOW=$(ask "Install it now via 'npx skills add mattpocock/skills --skill teach'? [y/N]:")
  if [[ "$INSTALL_NOW" =~ ^[Yy]$ ]]; then
    npx skills@latest add mattpocock/skills --skill teach
    info "Installed. If it created .agents instead of .claude (or vice versa), you may still need to symlink them — the next step checks for that."
  else
    warn "Skipping install — continuing, but the cloud session won't have /teach unless it's added before you push."
  fi
else
  info "/teach skill found locally."
fi

# Look for the expected /teach artifacts as a light sanity check, warn only
EXPECTED=(MISSION.md RESOURCES.md lessons learning-records)
MISSING=()
for f in "${EXPECTED[@]}"; do
  [[ -e "$f" ]] || MISSING+=("$f")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  warn "Didn't find: ${MISSING[*]} — continuing anyway, but double check you're in the right folder."
fi

# ---------------------------------------------------------------------------
# 1. Init git repo if needed
# ---------------------------------------------------------------------------

if [[ ! -d .git ]]; then
  info "No git repo found here. Initializing one..."
  git init -b main
else
  info "Existing git repo found."
fi

# ---------------------------------------------------------------------------
# 2. Check .gitignore isn't excluding anything the skill needs
# ---------------------------------------------------------------------------

if [[ -f .gitignore ]]; then
  info "Checking .gitignore for entries that would exclude skill/progress files..."
  RISKY_PATTERNS=("\.claude" "\.agents" "lessons" "learning-records" "MISSION.md" "RESOURCES.md")
  FLAGGED=()
  for p in "${RISKY_PATTERNS[@]}"; do
    if grep -Eq "^${p}(/)?\$" .gitignore 2>/dev/null; then
      FLAGGED+=("$p")
    fi
  done
  if [[ ${#FLAGGED[@]} -gt 0 ]]; then
    warn "Your .gitignore currently excludes: ${FLAGGED[*]}"
    FIX=$(ask "Remove these lines from .gitignore so they get synced? [y/N]:")
    if [[ "$FIX" =~ ^[Yy]$ ]]; then
      for p in "${FLAGGED[@]}"; do
        sed -i.bak "/^${p}\/*\$/d" .gitignore
      done
      rm -f .gitignore.bak
      info "Updated .gitignore."
    else
      warn "Leaving .gitignore as-is — these files will NOT be pushed."
    fi
  else
    info ".gitignore looks fine, nothing risky excluded."
  fi
fi

# ---------------------------------------------------------------------------
# 3. Check .claude / .agents symlink situation
# ---------------------------------------------------------------------------

if [[ -L .agents && -d .claude ]]; then
  info ".agents is a symlink to .claude — checking git will actually track it..."
  if git check-ignore -q .agents 2>/dev/null; then
    warn ".agents is being ignored by git. Removing any matching .gitignore rule is required for the cloud session to see your skill."
  else
    info "Symlink looks trackable. git stores symlinks as symlinks, which is fine as long as GitHub resolves them (it does, for same-repo relative links)."
  fi
elif [[ -d .claude && ! -e .agents ]]; then
  info "Found .claude only (no .agents symlink) — that's fine as long as your cloud session uses Claude Code directly."
fi

# ---------------------------------------------------------------------------
# 4. Stage, verify, and commit
# ---------------------------------------------------------------------------

info "Staging files..."
git add -A

info "Verifying the skill folder and progress files are actually tracked..."
TRACK_CHECK=(".claude" ".agents" "lessons" "learning-records" "MISSION.md" "RESOURCES.md")
for f in "${TRACK_CHECK[@]}"; do
  if [[ -e "$f" ]]; then
    if git ls-files --error-unmatch "$f" >/dev/null 2>&1 || git ls-files -- "$f" | grep -q .; then
      echo "   ✓ $f is tracked"
    else
      warn "   $f exists locally but is NOT tracked by git — check .gitignore or file permissions."
    fi
  fi
done

COMMIT_MSG=$(ask "Commit message [default: 'sync /teach progress']:")
COMMIT_MSG=${COMMIT_MSG:-"sync /teach progress"}

if git diff --cached --quiet; then
  info "Nothing new to commit."
else
  git commit -m "$COMMIT_MSG"
  info "Committed."
fi

# ---------------------------------------------------------------------------
# 5. Set up the GitHub remote
# ---------------------------------------------------------------------------

if git remote get-url origin >/dev/null 2>&1; then
  ORIGIN_URL=$(git remote get-url origin)
  info "Remote 'origin' already set: $ORIGIN_URL"
else
  info "No remote configured yet."
  if command -v gh >/dev/null 2>&1; then
    USE_GH=$(ask "GitHub CLI (gh) detected — use it to create the repo automatically? [y/N]:")
    if [[ "$USE_GH" =~ ^[Yy]$ ]]; then
      REPO_NAME=$(ask "Repo name (e.g. teach-progress):")
      gh repo create "$REPO_NAME" --private --source=. --remote=origin --push
      info "Private repo created and pushed via gh."
      SKIP_MANUAL_PUSH=1
    fi
  fi

  if [[ -z "${SKIP_MANUAL_PUSH:-}" ]]; then
    REPO_URL=$(ask "Paste your GitHub repo URL (create an empty PRIVATE repo on github.com first, e.g. https://github.com/you/teach-progress.git):")
    git remote add origin "$REPO_URL"
    info "Remote added."
  fi
fi

# ---------------------------------------------------------------------------
# 6. Push
# ---------------------------------------------------------------------------

if [[ -z "${SKIP_MANUAL_PUSH:-}" ]]; then
  CURRENT_BRANCH=$(git branch --show-current)
  info "Pushing '$CURRENT_BRANCH' to origin..."
  git push -u origin "$CURRENT_BRANCH"
fi

echo
info "Done. Your repo is synced to GitHub."
echo "Next steps:"
echo "  1. On your phone, open claude.ai/code or the Claude Android app."
echo "  2. Start a new cloud session and point it at this repo."
echo "  3. Confirm the /teach skill loads (run /help or check the skill is listed)."
echo "  4. Work a lesson, then have the agent commit + push its own changes."
echo "  5. Back on your laptop: git pull"

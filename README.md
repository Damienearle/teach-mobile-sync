# teach-mobile-sync

Sync your [`/teach`](https://www.aihero.dev/learn-anything-with-my-teach-skill) study plan (Matt Pocock's Claude Code skill) between your laptop and your phone — so you can keep learning on the go and pick up right where you left off.

This is a **Claude Code Skill**, `teach-sync`. Run it from inside a Claude Code session and it conversationally pushes your `/teach` project to a private GitHub repo, so you can open that project in a Claude Code cloud session from your phone — for when your laptop is off, traveling, or otherwise unreachable.

## Install

`teach-sync` is installed via [`npx skills`](https://github.com/vercel-labs/skills). Pick one:

**Global (recommended)** — install once, use it from any `/teach` project:

```bash
npx skills add Damienearle/teach-mobile-sync --skill teach-sync -g
```

**Project-local** — installs into the current project's own `.claude/skills/teach-sync/`, version-pinned and committed with it. Run this from inside the target `/teach` project instead:

```bash
npx skills add Damienearle/teach-mobile-sync --skill teach-sync
```

## Quick start

Inside a Claude Code session, from your `/teach` project's root (or anywhere, if you pass a path):

```
/teach-sync

# or, to create a brand-new topic folder and sync it in one go:
/teach-sync path/to/new-topic
```

Claude will walk you through it conversationally — confirming the directory, checking whether `/teach` itself is installed, flagging any `.gitignore` risk, and setting up the private GitHub repo — asking questions in chat rather than shell prompts.

## What it does

1. Confirms the target project folder (or creates the one you pass it)
2. Checks the `/teach` skill itself is installed, offering to install it if not
3. Initializes git if needed
4. Checks `.gitignore` isn't accidentally hiding your skill folder or progress files
5. Verifies the `.claude`/`.agents` skill folder and `learning-records/` are actually tracked by git
6. Commits your changes
7. Creates a **private** GitHub repo (via `gh` CLI if you have it, or asks for a repo URL) and pushes
8. Walks through next steps — including the easy-to-miss Claude GitHub App install, and a reminder to run `/teach` if the project doesn't look fully set up yet

Public repos are never offered — this is personal learning progress, kept private.

## Using it from your phone

Once pushed:

1. Connect GitHub to Claude once, at claude.ai → Settings → GitHub — and install the **Claude GitHub App** on your repo (this is the step that's easy to miss; OAuth alone won't let cloud sessions push changes back)
2. On your phone: Claude app → Code tab → New session → select your repo
3. Work a lesson — the agent commits and pushes automatically as it finishes
4. Back at your laptop: `git pull`

Full walkthrough in [`INSTRUCTIONS.md`](./INSTRUCTIONS.md).

## Requirements

- Claude Code
- Git
- Bash — the skill's scripts are Bash, not PowerShell/cmd. On Windows this
  means [Git Bash](https://git-scm.com/downloads) (bundled with Git for
  Windows) or WSL; on macOS/Linux the system shell already provides it
- [GitHub CLI](https://cli.github.com/) (optional, but recommended — lets the skill create the repo for you)
- A GitHub account

## License

MIT

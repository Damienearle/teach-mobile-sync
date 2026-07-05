# teach-mobile-sync

Sync your [`/teach`](https://www.aihero.dev/learn-anything-with-my-teach-skill) study plan (Matt Pocock's Claude Code skill) between your laptop and your phone — so you can keep learning on the go and pick up right where you left off.

This toolkit pushes your project to a private GitHub repo so you can open it in a Claude Code cloud session from your phone — for when your laptop is off, traveling, or otherwise unreachable.

## Quick start

```bash
git clone https://github.com/Damienearle/teach-mobile-sync.git
cd your-teach-project        # cd into YOUR /teach project, not this repo
/path/to/teach-mobile-sync/setup-teach-sync.sh
```

Or just download `setup-teach-sync.sh` directly and run it from your `/teach` project root.

**On Windows:** use Git Bash (right-click your project folder → "Git Bash Here") or WSL. This won't run in PowerShell/cmd as-is.

## What the script does

1. Confirms you're in the right project folder
2. Initializes git if needed
3. Checks `.gitignore` isn't accidentally hiding your skill folder or progress files
4. Verifies the `.claude`/`.agents` skill folder and `learning-records/` are actually tracked by git
5. Commits your changes
6. Creates a **private** GitHub repo (via `gh` CLI if you have it, or prompts for a repo URL) and pushes

Public repos aren't offered — this is personal learning progress, keep it private.

## Using it from your phone

Once pushed:

1. Connect GitHub to Claude once, at claude.ai → Settings → GitHub — and install the **Claude GitHub App** on your repo (this is the step that's easy to miss; OAuth alone won't let cloud sessions push changes back)
2. On your phone: Claude app → Code tab → New session → select your repo
3. Work a lesson — the agent commits and pushes automatically as it finishes
4. Back at your laptop: `git pull`

Full walkthrough in [`INSTRUCTIONS.md`](./INSTRUCTIONS.md).

## Requirements

- Git
- [GitHub CLI](https://cli.github.com/) (optional, but recommended — lets the script create the repo for you)
- A GitHub account

## License

MIT

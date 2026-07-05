# Syncing /teach to Your Phone via GitHub

Use this to continue your `/teach` study plan from your phone.

---

## One-time setup (laptop side)

1. Install the `teach-sync` Claude Code skill once, so it's available for every future topic:
   ```
   npx skills add Damienearle/teach-mobile-sync --skill teach-sync -g -a claude-code
   ```
   (`-g` installs it globally, to `~/.claude/skills/teach-sync/`, so it works from any `/teach` project without reinstalling. Drop `-g` to install it into just the current project instead, version-pinned and committed with it. `-a claude-code` scopes the install to Claude Code only — without it, `npx skills` defaults to also wiring up ~40 other coding agents it supports via a shared `~/.agents/skills/` copy and per-agent symlinks, and one of those default targets, `promptscript`, has a known bug that errors out on global installs.)

2. Then, for each `/teach` project you want synced, inside a Claude Code session:
   ```
   /teach-sync                    # existing topic, run from its root
   /teach-sync path/to/new-topic  # or, create a brand-new topic folder and sync it in one go
   ```

   Unlike a plain shell script, this is conversational — Claude asks you things in chat rather than stopping at rigid `[y/N]` prompts, and uses judgment about what to suggest (e.g. whether to nudge you toward installing `/teach` first). Under the hood it will:
   - Confirm the project folder (or create the one you pass it)
   - Check the `/teach` skill itself is installed, offering to install it if missing
   - Init git if needed
   - Check `.gitignore` isn't hiding your skill folder or progress files
   - Verify the `.claude`/`.agents` skill folder and `learning-records/` are actually tracked
   - Create a **private** GitHub repo (via `gh` CLI if installed, or ask you for a repo URL) and push
   - Walk through next steps, including a reminder if the project still needs a `/teach` session to build out `MISSION.md`/`RESOURCES.md`/`lessons/`

3. Connect GitHub to Claude (only needs doing once, ever):
   - Go to claude.ai → Settings → connect GitHub (OAuth)
   - Install the **Claude GitHub App** on this specific repo — this is the step people miss. OAuth alone only gives read access; without the App install, cloud-session pushes silently fail with a 403 even though everything else looks connected.

4. Install the Claude Android app if you don't have it yet — run `/mobile` inside Claude Code to get a download QR. You'll need it to open cloud sessions from the Code tab.

### Every time you want to work remotely without the laptop

1. On your phone: open the Claude Android app → Code tab → New session → select your repo
2. It clones a fresh copy into a cloud sandbox — same skill, same progress files, since it's reading from GitHub
3. Tell it what lesson to run, same as you would locally
4. It commits and pushes automatically as it finishes work (usually to a branch like `claude/lesson-3-xxxxx`, not straight to `main`)
5. Back at your laptop, whenever it's next on:
   ```
   git pull
   ```
   (if it pushed to a branch instead of `main`, merge that branch or pull it directly)

**Gotchas:**
- Cloud sessions start from a **fresh clone** — anything only configured locally on your laptop (not committed) won't be there.
- The agent tends to push proactively without asking. If you want more control, add a line to your project's `CLAUDE.md`:
  - `"Always ask before pushing"` — for manual approval, or
  - `"Commit and push after each completed lesson"` — to make the automatic behavior explicit and predictable

---

## Setting this up for the first time

- GitHub's free plan includes unlimited **private** repos at no cost — you can create a repo for every new study topic to take on the road.
- Bookmark `claude.ai/code` to your phone's home screen (Chrome → Add to Home Screen) so opening a cloud session is one tap.
- **Starting a brand-new topic?** `/teach-sync` only handles the git/GitHub side — it doesn't generate your actual study plan. Two orders work, depending on where you want to run `/teach`:
  - **Recommended — `/teach` first, locally:** create/`cd` into the new topic folder yourself, run `/teach` (it asks what you want to learn and builds `MISSION.md`, `RESOURCES.md`, `lessons/`), then run `/teach-sync`. Since `MISSION.md` already exists, `/teach-sync` suggests a repo name based on your actual topic instead of the folder name — one pass, nothing to rename later.
  - **Repo-first — e.g. you want to run `/teach` from a cloud session instead:**
    1. `/teach-sync path/to/new-topic` — creates the folder, offers to install the `/teach` skill into it, and pushes a private repo (named after the folder, since there's no topic yet).
    2. Run `/teach` — locally, or in a cloud session pointed at that repo — to build out `MISSION.md`, `RESOURCES.md`, and `lessons/`.
    3. Run `/teach-sync` again (or let the agent commit/push) to sync the real study plan up. It'll offer to rename the repo to match the real topic now that one exists — purely optional.

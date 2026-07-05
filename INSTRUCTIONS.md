# Syncing /teach to Your Phone via GitHub

Use this to continue your `/teach` study plan from your phone.

---

## One-time setup (laptop side)

1. Install the `teach-sync` Claude Code skill once, so it's available for every future topic:
   ```
   npx skills add Damienearle/teach-mobile-sync --skill teach-sync -g -a claude-code
   ```
   (`-g` installs it globally, to `~/.claude/skills/teach-sync/`, so it works from any `/teach` project without reinstalling. Drop `-g` to install it into just the current project instead, version-pinned and committed with it. `-a claude-code` scopes the install to Claude Code only — without it, `npx skills` defaults to also wiring up ~40 other coding agents it supports via a shared `~/.agents/skills/` copy and per-agent symlinks, and one of those default targets, `promptscript`, has a known bug that errors out on global installs.)

2. Install `/teach` itself too (Matt Pocock's skill — a separate project this one builds on), the same way:
   ```
   npx skills@latest add mattpocock/skills --skill teach -g -a claude-code
   ```
   Do this in whatever terminal/session is convenient — it doesn't need to be inside a `/teach` project folder. **Important:** a skill installed mid-conversation doesn't show up in that same conversation — Claude Code loads its slash-command list once, when a session starts. If you install `/teach` while a Claude Code session is already open, that session won't see it; open a *new* one before running `/teach`. Installing it here, ahead of time, avoids that entirely.

3. Connect GitHub to Claude (only needs doing once, ever):
   - Go to claude.ai → Settings → connect GitHub (OAuth)
   - Install the **Claude GitHub App** on this specific repo — this is the step people miss. OAuth alone only gives read access; without the App install, cloud-session pushes silently fail with a 403 even though everything else looks connected.

4. Install the Claude Android app if you don't have it yet — run `/mobile` inside Claude Code to get a download QR. You'll need it to open cloud sessions from the Code tab.

## Starting a new topic

`/teach` builds the study plan; `/teach-sync` pushes it to GitHub. They're separate, user-invoked skills — neither one runs the other automatically. Two orders work:

**Recommended — `/teach` first, then `/teach-sync`:**

1. Create/`cd` into the new topic folder yourself.
2. In a session started *after* both skills were installed, run `/teach` — it asks what you want to learn and builds `MISSION.md`, `RESOURCES.md`, `lessons/`.
3. Run `/teach-sync`. Since `MISSION.md` already exists, it suggests a repo name based on your actual topic instead of the folder name — one pass, nothing to rename later.

**Repo-first — e.g. you'd rather run `/teach` from a cloud session:**

1. `/teach-sync path/to/new-topic` — creates the folder, offers to install the `/teach` skill into it, and pushes a private repo (named after the folder, since there's no topic yet).
   - If `/teach` wasn't already installed and you have it install it now during this run, remember: it won't be invocable in *this* conversation. Open a new Claude Code session in the folder — locally, or a cloud session pointed at the freshly pushed repo — before running `/teach`.
2. Run `/teach` there to build out `MISSION.md`, `RESOURCES.md`, and `lessons/`.
3. Run `/teach-sync` again (or let the agent commit/push) to sync the real study plan up. It'll offer to rename the repo to match the real topic now that one exists — purely optional.

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

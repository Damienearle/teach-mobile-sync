# Syncing /teach to Your Phone via GitHub

Use this to continue your `/teach` study plan from your phone.

---

## One-time setup (laptop side)

1. Make sure your `/teach` project folder is in a git repo. If you have the `setup-teach-sync.sh` script, just run it from the project root:
   ```
   cd /path/to/your/teach-project
   chmod +x setup-teach-sync.sh
   ./setup-teach-sync.sh
   ```
   It will:
   - Init git if needed
   - Check `.gitignore` isn't hiding your skill folder or progress files
   - Verify the `.claude`/`.agents` skill folder and `learning-records/` are actually tracked
   - Create a **private** GitHub repo (via `gh` CLI if installed, or prompt you for a repo URL) and push

2. Connect GitHub to Claude (only needs doing once, ever):
   - Go to claude.ai → Settings → connect GitHub (OAuth)
   - Install the **Claude GitHub App** on this specific repo — this is the step people miss. OAuth alone only gives read access; without the App install, cloud-session pushes silently fail with a 403 even though everything else looks connected.

3. Install the Claude Android app if you don't have it yet — run `/mobile` inside Claude Code to get a download QR. You'll need it to open cloud sessions from the Code tab.

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

- GitHub's free plan includes unlimited **private** repos at no cost — You can create a repo for every new study topic to take on the road.
- Bookmark `claude.ai/code` to your phone's home screen (Chrome → Add to Home Screen) so opening a cloud session is one tap.

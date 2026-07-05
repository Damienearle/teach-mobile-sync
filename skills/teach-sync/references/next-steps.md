# Next-steps checklists

Quote one of these two variants verbatim as the closing message, chosen by
whether `TEACH_ARTIFACTS_MISSING` (from `check.sh`) was empty or not. Append
whichever of the extra callouts below apply, on top of the chosen variant.

Both variants always lead with the GitHub App reminder — it is the single
most-missed step, and cloud-session pushes fail with a silent 403 without it.

## Variant A — `TEACH_ARTIFACTS_MISSING` is non-empty (project not fully set up yet)

```
Next steps:
  1. Install the Claude GitHub App on this repo (one-time per repo):
     claude.ai -> Settings -> GitHub -> install the App (not just OAuth).
     OAuth alone won't let cloud sessions push changes back (fails with a 403).
  2. This doesn't look like a fully set-up /teach project yet (missing: <list>).
     Open a new Claude Code session in this folder — locally, or a cloud session
     pointed at this repo — and run the /teach skill to build out your study plan
     (it will ask what you want to learn and create MISSION.md, RESOURCES.md,
     lessons/). It needs to be a session that starts *after* /teach was installed,
     since a session already running won't see a skill installed mid-conversation.
     Once it's done, commit + push again (re-run /teach-sync, or let the agent do it).
  3. On your phone, open claude.ai/code or the Claude Android app.
  4. Start a new cloud session and point it at this repo.
  5. Confirm the /teach skill loads (run /help or check the skill is listed).
  6. Work a lesson, then have the agent commit + push its own changes.
  7. Back on your laptop: git pull
```

## Variant B — `TEACH_ARTIFACTS_MISSING` is empty (fully set up)

```
Next steps:
  1. Install the Claude GitHub App on this repo (one-time per repo):
     claude.ai -> Settings -> GitHub -> install the App (not just OAuth).
     OAuth alone won't let cloud sessions push changes back (fails with a 403).
  2. On your phone, open claude.ai/code or the Claude Android app.
  3. Start a new cloud session and point it at this repo.
  4. Confirm the /teach skill loads (run /help or check the skill is listed).
  5. Work a lesson, then have the agent commit + push its own changes.
  6. Back on your laptop: git pull
```

## Extra callout — only if the repo name came from the folder, not a real topic (`REPO_NAME_SOURCE=folder_name` in step 7)

Append this as its own short line, phrased as an offer the user can take or
leave — it's cosmetic, so don't make it sound like a pending task:

```
Since /teach hadn't run yet, I named the repo after the folder ('<SUGGESTED_REPO_NAME>').
Once you know the real topic, want me to rename it? Totally optional, and easy to do
later yourself too: `gh repo rename <new-name>`, run from inside the project — it
updates your local `origin` remote to match automatically.
```

## Extra callout — only if `/teach` was just installed during this conversation

Append this as its own short, clearly separated line — don't let it get lost
in the checklist above. This is the common case, and the one most likely to
confuse someone who just watched the install apparently succeed:

```
Heads up: /teach installed successfully, but this chat session was already running
before that happened, so it won't show up as a command here. Open a *new* Claude
Code session in this folder and run /teach there.
```

## Extra callout — only if the user declined to install `/teach` during this run

Append this as its own short, clearly separated line — don't let it get lost
in the checklist above:

```
Note: /teach isn't installed in this project yet. The cloud session won't have it
until it's added — install it before your next push (npx skills@latest add
mattpocock/skills --skill teach), or run /teach-sync again to be asked again.
```

---
name: teach-sync
description: Pushes a /teach study-plan project to a private GitHub repo — git init, gitignore/symlink safety checks, commit, and remote setup — so the project can be resumed from a Claude Code cloud session or the mobile app. Also checks whether the /teach skill itself is installed in the target project and offers to install it.
disable-model-invocation: true
argument-hint: "[path/to/topic] — optional; target /teach project folder, created if it doesn't exist yet"
---

# teach-sync

Get a `/teach` study-plan project onto GitHub as a **private** repo, so it can be
resumed from a Claude Code cloud session or the mobile app when the laptop
isn't reachable. This is the natural step after (or before) a `/teach`
session: run it once a study plan exists to push progress, or run it first on
an empty folder to stand up a brand-new topic before `/teach` fills it in.

All paths below (`scripts/check.sh`, `scripts/apply.sh`,
`references/next-steps.md`) are relative to this file's own directory —
resolve that directory first and use absolute paths when invoking the
scripts, since this skill may be installed globally
(`~/.claude/skills/teach-sync/`) or per-project
(`./.claude/skills/teach-sync/`).

Two bundled scripts do all the deterministic work; never reimplement their
logic freehand and never invoke raw `git`/`gh` commands as a substitute for
them — they encode safety checks (private-repo-only, idempotent staging,
injection-safe commit messages) that matter to get right:

- `scripts/check.sh --dir PATH` — **read-only**. Reports facts about the
  target directory as `KEY=value` lines on stdout. Safe to run as often as
  needed; it never mutates anything.
- `scripts/apply.sh --dir PATH --stage STAGE [flags]` — **mutates**, once per
  stage (`init`, `gitignore`, `commit`, `remote`, `push`, or `all`). Never
  prompts interactively — every decision must already be made in
  conversation before calling it.

Invoke both with `bash <absolute path>/scripts/...`, not `./scripts/...`, so
behavior doesn't depend on executable bits surviving however the skill was
installed.

## 1. Resolve the target directory

If an argument was given (a path), that's the target. If it doesn't exist
yet, confirm with the user that creating it is intended (this is the
brand-new-topic case) before running `mkdir -p` — don't create it silently.

If no argument was given, don't assume the current directory is correct —
confirm with the user in chat that it's the intended `/teach` project root
before proceeding.

## 2. Run the preflight check

Run `bash <skill_dir>/scripts/check.sh --dir <target>` and parse its
`KEY=value` output. Use these facts to drive every decision below instead of
re-deriving them by inspecting files directly — `GITIGNORE_RISKY` is based on
matching exact `.gitignore` lines against a known list of risky patterns
(not a full `git check-ignore` evaluation), so it works correctly even
before `git init` has run, and it always agrees with what `apply.sh`'s
`gitignore` stage will actually strip. That also means it can miss less
literal cases (a broader glob like `learning-records/*`, or a blanket `*`
ignoring everything) — if something seems off despite `GITIGNORE_RISKY`
coming back empty, a manual `git check-ignore -v <path>` is the
authoritative check.

If `TARGET_DIR_EXISTS=no`, stop and tell the user the path doesn't exist (it
should have been created in step 1 already if intended).

## 3. Handle the `/teach` skill check

This is the main place to use judgment instead of a blind yes/no, branching
on `TEACH_SKILL_FOUND` and `TEACH_ARTIFACTS_MISSING`:

- **Not found, and the folder looks brand-new** (most or all of
  `TEACH_ARTIFACTS_MISSING` is populated — little or nothing exists yet):
  tell the user `/teach` isn't installed here, and suggest installing it now
  via `npx skills@latest add mattpocock/skills --skill teach` — there's
  nothing to lose yet, and this matches the natural order (stand up the
  empty repo first, let `/teach` fill it in second). Lean toward "yes,
  install now" as the default suggestion, but let the user decide.
- **Not found, but some artifacts already exist** (e.g. `MISSION.md` is
  there but no skill folder — deleted, or installed under a variant path the
  detection glob missed): this is unusual. Ask the user what happened before
  offering to reinstall over an already-in-progress project — don't
  silently reinstall.
- **Found**: say so briefly and move on. Don't manufacture a question when
  the answer is already obvious.
- **If the user declines to install**: continue with the sync anyway, but
  make sure the final next-steps message (step 9) clearly calls out that the
  cloud session won't have `/teach` until it's added before the next push —
  this warning must not get buried.
- **If install is run**: re-verify with a fresh `check.sh` call (cheap,
  read-only) rather than trusting the installer's own exit code — it can
  land files under an unexpected path.

## 4. Git init

If `GIT_REPO=no`, run `bash <skill_dir>/scripts/apply.sh --dir <target>
--stage init`. If already a repo, just note that and move on — no need to
narrate this step at length.

## 5. Gitignore and symlink safety

If `GITIGNORE_RISKY` is non-empty, explain plainly which lines are hiding
skill or progress files from git (and therefore from any cloud session that
clones the repo), then ask before running `apply.sh --stage gitignore
--fix-gitignore`. If the user declines, don't fix it, but make sure they
understand those files won't be synced.

If `AGENTS_SYMLINK=ignored`, treat it as the same problem — it's usually
caused by the same `.gitignore` entry — and fold it into the same
conversation rather than raising it as a separate interruption. If it's
`trackable` or `not_a_symlink`, mention it only in passing if at all.

## 6. Stage and commit

Propose a default commit message ("sync /teach progress") but invite the
user to give their own instead. Whatever message is used — default or
user-supplied — pass it via stdin, not as an inline shell argument, since a
chat-authored message may contain characters (backticks, `$()`, quotes) that
are unsafe to interpolate directly into a command line:

```
bash <skill_dir>/scripts/apply.sh --dir <target> --stage commit --commit-message-stdin <<'EOF'
<the message>
EOF
```

Check the exit code:
- **Exit 3** means there are no commits anywhere in this repo's history yet
  (a still-empty brand-new topic folder). Stop here — do not attempt the
  remote or push stages. Tell the user to go run `/teach` to build out the
  study plan, then come back and run `/teach-sync` again.
- **Exit 0** means proceed to the next step (this includes the case where
  there was nothing new to commit but prior history already exists).

## 7. Remote setup — private repos only

If `REMOTE_ORIGIN` from the preflight check is already set, skip this step
entirely.

Otherwise, branch on `GH_CLI` and `GH_AUTHENTICATED` from the preflight
check:

- **`GH_CLI=yes` and `GH_AUTHENTICATED=yes`** (the smooth path — and what
  every sync after the first one should look like): offer to create the
  repo via `gh`. `SUGGESTED_REPO_NAME` is only a suggestion — always ask in
  chat before using it, and use whatever name the user gives instead if they
  offer one. How to phrase the ask depends on `REPO_NAME_SOURCE`:
  - `mission_topic` — `MISSION.md` already exists, so the name was derived
    from its actual topic (`MISSION_TOPIC`). E.g. "Based on your mission
    ('`<MISSION_TOPIC>`'), I'd suggest '`<SUGGESTED_REPO_NAME>`' for the repo
    name — sound good, or would you rather use something else?"
  - `folder_name` — no `MISSION.md` yet (this is a brand-new topic `/teach`
    hasn't run on), so the name just comes from the folder. Say so plainly,
    e.g. "I don't have a real topic yet since `/teach` hasn't run here, so
    I'd suggest naming the repo '`<SUGGESTED_REPO_NAME>`' after the folder for
    now — happy to use a different name, or you can rename it later once you
    know the topic (see the closing notes)."

  Once the user has confirmed a name (suggested or their own), run:

  ```
  bash <skill_dir>/scripts/apply.sh --dir <target> --stage remote --gh-create-repo <name> --gh-bin "<GH_BIN>"
  ```

  Always pass `--gh-bin "<GH_BIN>"` (verbatim from `check.sh`'s output), not
  a bare `gh` — see the `GH_CLI=no` bullet below for why.

- **`GH_CLI=yes` but `GH_AUTHENTICATED=no`**: `gh` is installed but not
  logged in. `gh auth login` is an interactive, browser-based flow, so it
  has to happen in the user's own terminal — `apply.sh` never prompts and
  this skill can't drive it for them. Tell them to run `gh auth login`
  themselves, then say when they're done (or just re-run `/teach-sync`) so
  a fresh `check.sh` call can confirm before proceeding down the path above.
  On Windows, if their terminal is Git Bash and `gh auth login` fails with
  "could not prompt: Incorrect function" / a MinTTY warning, tell them to
  either run `winpty gh auth login` instead (same window), or run that one
  command from PowerShell/cmd.exe — Git Bash's default terminal (MinTTY)
  doesn't support the interactive prompt gh needs.

- **`GH_CLI=no`**: give them the one-line install command for their platform
  (e.g. `winget install --id GitHub.cli`, `brew install gh`, or
  `sudo apt install gh`), and mention that `gh auth login` (same interactive
  caveat as above) is still needed after installing. This is a one-time
  setup cost — once `gh` is installed and authenticated, every subsequent
  `/teach-sync` on any project uses the smooth path above with no manual
  copy-pasting. After they say they've installed it, re-run `check.sh`
  rather than assuming it worked. `GH_BIN` resolves via a fallback list of
  common install locations if a bare `gh` isn't on `PATH` yet, so this
  usually keeps working in the same terminal session without needing a
  restart — a fresh install often isn't on `PATH` in a shell that was
  already open when it was installed. Only if `GH_CLI` is still `no` after
  a real install does the shell genuinely not know where it landed (e.g.
  installed somewhere `find_gh_bin` doesn't check); restarting the terminal
  is the fallback fix in that case.

- **If the user prefers not to use `gh` at all**, regardless of whether it's
  installed or authenticated: fall back to a manual, copy-paste-able
  checklist rather than a vague "go create a repo":

  1. Go to https://github.com/new
  2. Repository name: `<SUGGESTED_REPO_NAME>` (or their own choice)
  3. Set visibility to **Private**
  4. Leave "Initialize this repository with a README" **unchecked** — the
     local repo already has commits from step 6, and a README created on
     GitHub's side would conflict with that history
  5. Click **Create repository**, then copy the HTTPS URL it shows

  Then run:

  ```
  bash <skill_dir>/scripts/apply.sh --dir <target> --stage remote --remote-url <url>
  ```

**Never present a public repo as an option, under any circumstance.** This
tool exists to sync personal learning progress and is scoped to private
repos only — `apply.sh` has no `--public` flag at all, so there is no way to
create one through this flow even by mistake. If the user explicitly asks
for a public repo, explain that this skill is intentionally scoped to
private repos and that they'd need to do that step manually outside this
flow.

## 8. Push

Unless the `remote` stage already pushed via `gh repo create ... --push`,
confirm with the user that they're ready to push before running:

```
bash <skill_dir>/scripts/apply.sh --dir <target> --stage push
```

This is idempotent — running it even when `gh` already pushed is harmless.
Don't skip the confirmation just because earlier stages already ran — each
mutating call in this flow should have its own explicit go-ahead in the
conversation, not an inherited one.

## 9. Next steps

Read `references/next-steps.md` and quote the matching variant verbatim
(Variant A if `TEACH_ARTIFACTS_MISSING` was non-empty, Variant B otherwise),
delivered conversationally rather than dumped as a raw block. Always include
the Claude GitHub App reminder — installing the App (not just OAuth) is the
single most-missed step, and skipping it makes cloud-session pushes fail
silently with a 403. If `/teach` install was declined in step 3, also
include the extra callout from that reference file. If the repo name came
from `REPO_NAME_SOURCE=folder_name` in step 7, also include that file's
rename callout — phrase it as an open offer the user can take or leave, not
a task they now owe you, since it's purely cosmetic and costs nothing to
skip.

## Common failure recovery

`apply.sh`'s mutating stages check the exit code of every git/gh command
they run and exit 1 with a description on stderr rather than reporting
success it didn't earn. A few failure modes are common enough to plan for
in conversation:

- **`gh repo create` fails** (in the `remote` stage) — usually because the
  suggested name is already taken on the user's account, their `gh` session
  expired since `check.sh` ran, or a network blip. Show the user the actual
  error rather than guessing at it; then offer either a different repo name
  (retry the `remote` stage) or the manual `--remote-url` checklist from
  step 7 as a fallback.
- **`git push` fails because histories diverged** (in the `push` stage) —
  typically means the GitHub repo was created with "Initialize this
  repository with a README" checked despite step 7's instruction not to, or
  an existing non-empty repo was picked. Don't just retry the push; explain
  the conflict and offer `git pull --rebase origin <branch>` run manually by
  the user. Only mention `git push --force-with-lease` if the user
  explicitly confirms they want the local history to win and understands
  that discards the remote's differing commits.
- **`GH_AUTHENTICATED=yes` from `check.sh`, but `remote` or `push` still
  fails on auth** — a `gh` token can expire mid-conversation. Tell the user
  to re-run `gh auth login`, then re-run `check.sh` before retrying rather
  than assuming the earlier preflight result still holds.

## Guardrails recap

- Only ever create **private** repos — never offer or accept a public one.
- Preserve the step order above; later steps assume earlier ones already
  succeeded (e.g. don't attempt `remote`/`push` after a `commit` exit 3).
- Never mutate anything without having first checked `check.sh`'s current
  output — don't act on stale assumptions from earlier in a long
  conversation.
- Never invoke `apply.sh` interactively expecting it to prompt — it never
  will; all judgment happens in the conversation before each call.
- Every mutating `apply.sh` call needs its own explicit go-ahead from the
  user in chat — don't chain straight into the next stage just because the
  previous one succeeded. The script only ever does what's already been
  agreed to; it never decides anything on its own.
- Never attempt to run or automate `gh auth login` on the user's behalf —
  it's an interactive, browser-based OAuth flow that must run in their own
  terminal; the skill can only detect its state (`GH_AUTHENTICATED`) and
  tell the user what to run.

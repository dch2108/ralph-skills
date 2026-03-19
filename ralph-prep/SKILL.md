---
name: ralph-prep
metadata:
  version: '2.1'
  author: dch2108
description: >
  Prepare the environment for a new Ralph Wiggum autonomous coding loop.
  Validates prerequisites, copies the loop script, and reports readiness.
  Use when the user says "prepare for Ralph", "set up the loop", "ralph prep",
  "start a new Ralph run", "get ready for AFK coding", or "prep the loop".
  Do NOT use for creating the task list (use plan-to-ralph for that).
---

# Ralph Prep

Validate the environment for a Ralph loop run. Fast — should complete in 30 seconds.

## Instructions

### Check 1: Git repo

**Hard gate.** Nothing else runs until this passes.

```bash
git rev-parse --is-inside-work-tree
```

- **Not a git repo:** STOP. "This project is not a git repository. Ralph requires git. Run `git init && git add -A && git commit -m 'initial commit'` first."
- **Dirty working tree:** Warn: "Working tree has uncommitted changes. Recommend committing or stashing." Let the user decide.
- **Previous run complete:** If PLAN.md exists and has zero `- [ ]` lines (all tasks checked), offer to archive:
  ```
  mkdir -p archive/ralph-$(date +%Y-%m-%d)
  mv PLAN.md progress.txt BACKLOG.md archive/ralph-$(date +%Y-%m-%d)/ 2>/dev/null
  git add archive/ && git commit -m "chore: archive Ralph run"
  ```
- **Clean tree:** Pass. Continue.

### Check 2: Plan exists

- `PLAN.md` must exist in the project root.
- Must have at least one unchecked item (`- [ ]`).
- **Missing:** "No PLAN.md found. Run `/plan-to-ralph` first."
- **All checked:** "All tasks are done. Create a new plan with `/plan-to-ralph`."
- **Has unchecked items:** Report: "Found N unchecked tasks in PLAN.md."

### Check 2b: AGENTS.md sanity check

Scan `AGENTS.md` (or `CLAUDE.md`) for stale references that will break the loop:

- **`IMPLEMENTATION_PLAN.md`** — v1 artifact. Ralph v2 uses `PLAN.md`. If found, offer to fix: replace all occurrences with `PLAN.md` and show the diff to the user.
- **`implementation.plan`** or **`implementation_plan`** — same issue, catch variant spellings.

If stale references are found and the user approves the fix, apply it before continuing. If the user declines, warn that the loop will likely fail and continue.

### Check 3: Feedback loops work

Ralph without feedback loops produces broken code silently. This is the safety gate.

Read `AGENTS.md` (or `CLAUDE.md`). Look for feedback loop commands (typecheck, lint, test, build).

**If no feedback section exists:** STOP. "AGENTS.md has no feedback loop commands. Run `/setup-ralph` to configure project tooling, then re-run `/ralph-prep`."

For each command listed, run it with `timeout 120`:

```
| Feedback loop | Command           | Result          |
|---------------|-------------------|-----------------|
| Typecheck     | npm run typecheck | passing         |
| Tests         | npm test          | 42 passing      |
| Lint          | npm run lint      | command not found|
| Build         | npm run build     | success         |
```

- **Command not found:** STOP. "Feedback command `[cmd]` is listed in AGENTS.md but not installed. Run `/setup-ralph` to install tooling."
- **Command times out:** STOP. "`[cmd]` did not complete in 120s — may be in watch mode. Update AGENTS.md to use a run-once command."
- **Command fails (but exists):** Warn: "[Tool] has existing failures. Ralph will try to fix these AND your plan tasks." Let user decide.

### Copy ralph.sh

Always copy the canonical template to the project root. This ensures v1→v2 migration and picks up any template improvements.

```bash
# Archive old ralph.sh if it exists and differs
if [ -f ralph.sh ]; then
  mkdir -p archive/ralph-prep-backup
  cp ralph.sh archive/ralph-prep-backup/ralph.sh.$(date +%Y%m%d%H%M%S)
fi

# Copy canonical template
cp ralph-prep/references/ralph-template.sh ralph.sh 2>/dev/null \
  || cp "$(find ~/.claude/skills -path '*/ralph-prep/references/ralph-template.sh' -print -quit 2>/dev/null)" ralph.sh
chmod +x ralph.sh
```

### Report

```
## Ralph Prep — Ready

| Check            | Status                                    |
|------------------|-------------------------------------------|
| Git repository   | clean working tree on branch main         |
| Plan             | 12 unchecked tasks in PLAN.md             |
| Feedback: type   | npm run typecheck — passing                |
| Feedback: test   | npm test — 42 passing                      |
| Feedback: lint   | npm run lint — clean                       |
| Feedback: build  | npm run build — success                    |
| Loop script      | ralph.sh copied from template              |

### How to run:

  ./ralph.sh           # one iteration, watch live (default)
  ./ralph.sh 10        # 10 iterations AFK
```

If any check fails, mark it with an X and explain what to fix.

**NEVER execute ralph.sh from this skill.** Prep validates and reports. The user starts the loop in a separate terminal.

## Troubleshooting

### Not a git repository
Run `git init && git add -A && git commit -m 'initial commit'` before ralph-prep.

### No test suite / no feedback loops
Run `/setup-ralph` to install a test runner and configure feedback loops, then re-run `/ralph-prep`.

### ralph.sh doesn't work after upgrade
ralph-prep always copies a fresh template. If it still fails, check that `references/ralph-template.sh` exists in the skill directory.

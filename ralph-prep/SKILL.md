---
name: ralph-prep
metadata:
  version: '1.3'
  author: dch2108
description: >
  Prepare the environment for a new Ralph Wiggum autonomous coding loop.
  Validates prerequisites, archives previous runs, ensures the loop script
  exists and is configured, and verifies AGENTS.md is lean and ready.
  Use when the user says "prepare for Ralph", "set up the loop", "ralph prep",
  "start a new Ralph run", "get ready for AFK coding", or "prep the loop".
  Do NOT use for creating the task list (use review-to-plan for that).
---

> **Note:** If using in Claude Code, add `disable-model-invocation: true` to the
> frontmatter above to prevent auto-triggering. This skill has side effects
> (archiving files, creating scripts) and should only run on explicit invocation.

# Ralph Prep

Prepare the environment for a fresh Ralph Wiggum loop run.

## Philosophy

Every Ralph iteration starts with a fresh context window. The only things that persist are files on disk and git history. This skill ensures those files are clean, correct, and minimal before the loop begins.

Key principles (per Geoffrey Huntley):

- **Deterministic context allocation.** Every iteration loads the same files. Keep them small.
- **Fresh context per iteration.** No conversation history carries over. The plan and AGENTS.md are the agent's entire world.
- **Backpressure is mandatory.** Without feedback loops (tests, types, linting), the agent will silently produce broken code.
- **Isolation for AFK runs.** Docker sandboxes prevent runaway agents from damaging the host.
- **Subagents are child processes, not peers.** Spawn subagents for I/O-heavy reconnaissance and parallel writes. Keep strategy and implementation in the main loop. Every tool call result gets malloc'd into the primary context — subagents burn through their own memory and return only a small summary.

## Instructions

### Step 1: Check for previous run artifacts

Look for these files in the project root:

- `IMPLEMENTATION_PLAN.md`
- `progress.txt`
- `BACKLOG.md`

**If any exist from a previous run:**

1. Check if the previous run is complete (all tasks marked `DONE` in the plan).
2. If complete or the user confirms the old run is finished, archive them:
   ```
   mkdir -p archive/ralph-[DATE]
   mv IMPLEMENTATION_PLAN.md progress.txt BACKLOG.md archive/ralph-[DATE]/ 2>/dev/null
   git add archive/ && git commit -m "chore: archive Ralph run [DATE]"
   ```
3. If the previous run is NOT complete, warn the user: "A previous Ralph run has incomplete tasks. Archive it anyway, or resume it?" Do NOT proceed without confirmation.

**If no previous artifacts exist**, skip to Step 2.

### Step 2: Verify and validate the implementation plan

Check that `IMPLEMENTATION_PLAN.md` exists in the project root.

- If it does NOT exist, tell the user: "No IMPLEMENTATION_PLAN.md found. Run `/review-to-plan` first to create one from your review findings." Do NOT proceed.

**If it exists, validate against [references/plan-schema.md](../references/plan-schema.md):**

1. **Parse YAML frontmatter.** Confirm the plan has a YAML frontmatter block (between `---` delimiters) containing: `plan_version`, `task_count`, `created`, `fields_used`. Flag any missing fields.
2. **Verify task_count.** Count the actual `### Task N:` headings. If the count does not match `task_count` in the frontmatter, block and report the mismatch.
3. **Validate per-task fields.** For each task, check that all required fields are present: **Priority**, **Status**, **Area**, **Description**, **Acceptance**. Report any tasks missing required fields.
4. **Check TODO count > 0.** Count tasks with `Status: TODO` or `Status: IN PROGRESS`. If zero (all tasks are DONE or the plan is empty), block: "All tasks are DONE — nothing for Ralph to work on. Create a new plan with `/review-to-plan` or add tasks manually."

If all checks pass, report: "Found valid plan with N tasks (M remaining). Proceed with prep?"

Do NOT proceed if any validation check fails.

### Step 3: Validate AGENTS.md

Check for `AGENTS.md` (or `CLAUDE.md`) in the project root.

**If it exists**, audit it for Ralph-readiness:

1. **Size check.** Count words. Flag if over 800 words — this will consume too much context per iteration. Recommend trimming to essentials only.
2. **Required sections.** Verify these sections exist (or suggest adding them):
   - Build/test commands (exact commands, not descriptions)
   - Feedback loop commands (typecheck, lint, test suite)
   - Commit conventions (if any)
   - Subagent rules (delegation boundaries)
3. **Bloat check.** Flag and recommend removing:
   - Code style rules that the codebase already demonstrates (LLMs are in-context learners — they pick up patterns from existing code)
   - Verbose explanations or rationale (the agent does not need to know *why*, only *what*)
   - Architecture documentation (move to `references/` or a separate doc)
   - Anything the agent can discover by reading the code

**If it does NOT exist**, create a minimal one:

```markdown
# AGENTS.md

## Build
[To be filled — e.g., `npm run build`, `cargo build`]

## Test
[To be filled — e.g., `npm test`, `pytest`]

## Typecheck
[To be filled — e.g., `npm run typecheck`, `mypy .`]

## Lint
[To be filled — e.g., `npm run lint`, `ruff check .`]

## Conventions
- One logical change per commit
- Run all feedback loops before committing
- Do NOT commit if any check fails

## Subagent Rules
- Before making changes, search the codebase using parallel subagents (do not assume something is not implemented)
- Delegate test/build runs to 1 subagent — never fan out builds
- Use subagents to study existing source code before modifying it
- Parallel subagents OK for independent file writes (e.g., updating 5 unrelated files)
- Use a subagent to update IMPLEMENTATION_PLAN.md and progress.txt after each task
- Do NOT delegate: task selection, implementation decisions, or the core fix itself
```

Ask the user to fill in the build/test/typecheck/lint commands for their project.

### Step 4: Validate or create the loop script

Check for `ralph.sh` (or `loop.sh`) in the project root or `scripts/` directory.

**If it exists**, validate:

1. It reads from `IMPLEMENTATION_PLAN.md` (or the plan file the user is using)
2. It passes `progress.txt` to the agent
3. It includes the `<promise>COMPLETE</promise>` exit condition (or equivalent)
4. It commits after each iteration

Report any issues found.

**If it does NOT exist**, generate one. Detect the environment:

```bash
# Check for Docker availability
if command -v docker &> /dev/null && docker info &> /dev/null 2>&1; then
  DOCKER_AVAILABLE=true
else
  DOCKER_AVAILABLE=false
fi

# Check for CLI tools
if command -v claude &> /dev/null; then
  CLI="claude"
elif command -v amp &> /dev/null; then
  CLI="amp"
elif command -v ollama &> /dev/null; then
  CLI="ollama"
else
  CLI="unknown"
fi
```

Generate `ralph.sh` using the template in [references/ralph-template.sh](references/ralph-template.sh).

For Docker-available environments (AFK mode), default to:
```
docker sandbox run $CLI -p ...
```

For non-Docker environments (HITL mode), use:
```
$CLI -p ...
```

Make the script executable: `chmod +x ralph.sh`

### Step 5: Validate feedback loops

Ralph without feedback loops produces broken code silently. This is the safety gate — **if feedback loops don't work, ralph.sh will NOT be generated.**

This step does NOT install tooling — it verifies that what's listed in AGENTS.md actually works. Tooling installation is a one-time project setup concern; use `/setup-feedback` for that.

**If AGENTS.md has no Feedback Loops section:** STOP. Tell the user: "AGENTS.md has no feedback loop commands. Run `/setup-feedback` to configure project tooling, then re-run `/ralph-prep`." Do NOT proceed.

Read the `## Feedback Loops` section from AGENTS.md. For each command listed:

1. Run it with a timeout (use `timeout 120` or equivalent to prevent watch-mode hangs).
2. Record: pass, fail (with errors), command not found, or timed out.

Report results as a table:

```
| Feedback loop | Command | Result |
|---------------|---------|--------|
| Typecheck | npm run typecheck | ✓ passing |
| Tests | npm test | ✓ 42 passing |
| Lint | npm run lint | ✗ command not found |
| Build | npm run build | ✓ success |
```

**If any command returns "not found":** STOP. Tell the user: "Feedback command `[command]` is listed in AGENTS.md but is not installed. Run `/setup-feedback` to install project tooling before prepping the loop." Do NOT generate ralph.sh.

**If any command times out:** STOP. Tell the user: "`[command]` did not complete within 120 seconds — it may be running in watch mode. Update the command in AGENTS.md to run once and exit (e.g., `vitest run` instead of `vitest`)." Do NOT generate ralph.sh.

**If any command fails (but exists):** Warn: "[Tool] has existing failures. Ralph will try to fix these AND your plan tasks — this may cause confusion. Recommend fixing existing failures first." Let the user decide whether to proceed.

**Auto-fix AGENTS.md:** If the commands in AGENTS.md don't match what actually works (e.g., lists `npm run typecheck` but the real command is `npx tsc --noEmit`), fix AGENTS.md to match reality. This is cleanup, not a blocking issue.

The feedback section should be terse — exact commands only, no explanations:

```markdown
## Feedback Loops (run before every commit)
1. Typecheck: `npm run typecheck`
2. Tests: `npm test`
3. Lint: `npm run lint`
4. Build: `npm run build`

Do NOT commit if any of these fail. Fix the failure first.
Delegate test/build output to 1 subagent — return only pass/fail + failure names and errors.
```

**Verify AGENTS.md subagent section:** Ensure `AGENTS.md` contains a `## Subagent Rules` section. If missing, add the one from the template above. If present, audit it:

- It should NOT instruct the agent to delegate task selection or implementation decisions
- It SHOULD instruct the agent to use subagents for codebase search, studying source, and test result summarization
- Build/test subagents must be capped at 1 (never fan out builds — hundreds of result summaries flood the primary context)
- It should be 4-8 lines max — terse rules, not explanations

### Step 6: Final readiness report

Present a summary:

```
## Ralph Prep — Ready

| Check | Status |
|-------|--------|
| Previous run archived | ✓ (archived to archive/ralph-2026-03-15/) |
| Implementation plan | ✓ (8 tasks, ~1,100 words) |
| AGENTS.md | ✓ (420 words — under budget) |
| Loop script | ✓ (ralph.sh with Docker, Claude Code CLI) |
| Feedback: typecheck | ✓ (npm run typecheck — passing) |
| Feedback: tests | ✓ (npm test — 42 passing) |
| Feedback: lint | ✓ (npm run lint — clean) |
| Feedback: build | ✓ (npm run build — success) |

Estimated context per iteration: ~3,200 tokens
  (AGENTS.md: ~600 tokens, plan: ~1,500 tokens, progress.txt: ~200 tokens, prompt: ~900 tokens)

### To start:
  HITL (watch): ./ralph.sh 1
  AFK (batch):  ./ralph.sh 10
```

If any check fails, mark it with ✗ and explain what needs to be fixed before the loop can run.

## Troubleshooting

### Problem: No test suite exists
Ralph without tests is dangerous. Feedback validation (Step 5) will block ralph.sh generation if tests are missing. Tell the user to run `/setup-feedback` to install a test runner and configure feedback loops, then re-run `/ralph-prep`.

### Problem: AGENTS.md is over 800 words
Help the user trim it. Common cuts:
- Remove code style rules (the codebase demonstrates these)
- Remove architecture explanations (move to a separate doc)
- Remove tool-specific instructions that the CLI already knows
- Consolidate verbose sections into terse command lists

### Problem: Previous ralph.sh uses a different plan file format
If the existing script references `prd.json` instead of `IMPLEMENTATION_PLAN.md`, ask the user which format to use. Update the script accordingly. Both formats work — consistency within a project matters more than format choice.

### Problem: Docker is not available but user wants AFK mode
Warn: "AFK mode without Docker runs the agent with full system access. Ensure you have good backups and the agent cannot access sensitive directories. Consider using `--dangerously-skip-permissions` only with a clean git state so you can revert."

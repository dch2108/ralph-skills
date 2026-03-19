# Changelog

## v2.0 — 2026-03-18

Complete rewrite. v1 over-formalized Huntley's methodology into a 30KB bureaucratic wizard. v2 returns to the source: simple, fast, operator-driven.

### Changed
- Plan format: `PLAN.md` is now a numbered checkbox list (was `IMPLEMENTATION_PLAN.md` with YAML frontmatter and structured task blocks)
- plan-to-ralph: 13KB -> 4KB. Three steps. No triage ceremony, no decomposition proof tables.
- ralph-prep: 19KB -> 3KB. Three checks + copy script. No wizard.
- ralph.sh prompt: ~6 lines (was ~50). AGENTS.md carries project-specific instructions.
- ralph-prep always overwrites ralph.sh from template (ensures v1->v2 migration)
- plan-schema.md: simple checkbox spec, references ralph.sh as parsing source of truth
- extract_next_task() now parses `- [ ]` checkbox lines instead of `### Task N:` blocks
- `CLAUDE_FLAGS` env var for passing flags to claude CLI (e.g., `--dangerously-skip-permissions`)

### Removed
- YAML frontmatter schema
- P0-P3 priority triage
- Mandatory decomposition check tables
- Input type detection (CEO/feature/review)
- Context budget estimation
- Model picker and cost estimation
- AGENTS.md bloat audit
- 9-point template validation checklist
- CLI auth check (ralph.sh fails fast if auth is bad)
- Docker sandbox path (reintroduce when needed)

### Why
Re-read [Huntley's blog post](https://ghuntley.com/ralph/). His actual approach: short prompt, AGENTS.md carries the weight, trust the loop, operator tunes by watching. v1 tried to prevent all failures upfront with process; v2 trusts the loop and the operator.

## v1.6 — 2026-03-18

Architectural fixes for the three structural failures from the first real-world run.

### Problem 1: HITL showed no output
**Root cause:** `echo "$prompt" | claude -p ... | tee` — two pipes. Claude detected non-tty on both stdin and stdout, buffered everything. Human stared at a blank terminal for 10+ minutes.

**Fix:** Replaced `| tee` with `script` (pseudo-tty allocator). `script -q logfile command` wraps the CLI in a pty so it thinks it's connected to a terminal and streams output live. The log file is written simultaneously by `script`, replacing tee's role.

### Problem 2: Agent completed all tasks in one iteration
**Root cause:** `build_prompt()` injected the full `@IMPLEMENTATION_PLAN.md`. The agent could see all TODO tasks. Telling it "only do one" was a prompt instruction fighting against visible work — the agent kept going.

**Fix:** New `extract_next_task()` function. Parses the plan, finds the first TODO task block (from `### Task N:` to the next heading), and injects ONLY that block into the prompt. The agent literally cannot see the other tasks. The prompt framing changed from "here's the full plan, only do one" to "here is your one task, this is your entire scope."

### Problem 3: Tasks were too large despite split rules
**Root cause:** plan-to-ralph had good split rules as passive text. The LLM read "split on 'and'" and then wrote "Create X that reads Y, defines Z, and outputs W" because no one forced it to count the verbs first.

**Fix:** Replaced passive rules with a mandatory decomposition check table. For every task, the skill must fill in: action verbs, APIs touched, new files, modified files, consumers. Each row has an automatic trigger (>1 verb → SPLIT, >1 API → SPLIT, etc.). The table IS the decision — no judgment required. Plus a one-sentence test: describe the task in ≤15 words with no "and/then/also". Tables must be shown to the user before writing the plan.

### Other changes
- Default iterations changed from 10 to 1 (HITL-first — user opts into batch with `./ralph.sh N`)
- Docker sandbox path removed from template (simplification — reintroduce when needed)
- Completion signal detection uses `grep` on log file instead of string match on variable (handles `script` escape codes)
- ralph-prep validation updated: checks for `extract_next_task`, `script` command, default-to-1

## v1.5 — 2026-03-18

Post-mortem fixes: Ralph completed all tasks in one iteration, showed no HITL progress, and tasks were too large.

### Fixed (ralph-template.sh)
- **Output now actually streams via `tee`** — v1.4 changelog claimed this but the code still captured into a variable. Now uses `| tee "$ITERATION_LOG"` so HITL mode shows real-time agent output.
- **One-task-per-iteration enforcement** — loop counts DONE tasks before/after each iteration and logs a violation if delta != 1. The prompt now explicitly tells the agent the loop will reject multi-task iterations.
- **Git repo preflight check** — `ralph.sh` now exits with a clear error if not in a git repo, instead of crashing mid-iteration on `git rev-parse`.
- **Prompt rewritten** — old prompt said "ONLY WORK ON A SINGLE TASK" as a suggestion. New prompt frames it as a structural constraint: "the loop will verify exactly one task changed" and "do NOT mark tasks DONE that you did not implement in THIS iteration."

### Fixed (ralph-prep)
- **Step 0: Git repo validation** — new hard gate before anything else runs. Checks for git repo, warns on dirty working tree.
- **Step 2: Task sizing audit** — flags tasks with "and" joining distinct work, descriptions > 3 sentences, and plans with < 6 tasks.
- **Step 4b: Template mandate** — ralph-prep now validates `ralph.sh` against `references/ralph-template.sh` for streaming, one-task enforcement, and git checks. If validation fails, replaces with a fresh template copy instead of generating ad-hoc.
- **Step 6: Readiness report** — now documents what the loop enforces (one task per iteration, git commit per task, streaming output) so users know what to expect.

### Fixed (plan-to-ralph)
- **Input type detection** — classifies input as granular code review, feature request, or CEO/founder plan. High-level inputs trigger a warning and aggressive decomposition.
- **Mandatory split rules** — five hard rules (not guidelines): split on "and", split on multiple APIs, split on create+consume, split on scaffold+logic, split on > 3 sentences. These are structural, not advisory.
- **Post-decomposition self-check** — mandatory checklist after writing all tasks. If any check fails, go back and split further.
- **Minimum 6 tasks** — plans with fewer than 6 tasks are flagged as likely too coarse.
- **Splitting example updated** — shows a real-world bad task (the briefing mega-prompt) decomposed into 5 proper tasks.

## v1.4 — 2026-03-17

Field-testing fixes: 10 issues from real-world Ralph loop usage.

### Changed
- ralph.sh is now the only valid loop script — ralph-prep archives all `.py`/`.js`/`.ts` variants unconditionally
- Stricter task sizing rules in plan-to-ralph aligned with Huntley methodology (split on "and", ~150 line rule, ~5 test rule)
- Git push moved to end of loop instead of after every iteration
- TODO status grep pattern fixed to match plan-schema.md format (`- **Status:** TODO`)

### Added
- Multi-model support: Claude (opus/sonnet/haiku) and Ollama with auto-detection picker in ralph-prep Step 4.5
- CLI auth check during prep (Step 4c) — catches "not logged in" before loop starts
- Cost estimation table and $50 budget cap (`COST_CAP_ITERATIONS`) in readiness report
- Machine-readable grep patterns section in plan-schema.md
- Explicit prohibition: ralph-prep NEVER auto-launches ralph.sh
- Sub-part guidance in ralph.sh prompt: implement only first sub-part if task has multiple parts

### Fixed
- Word-splitting bug in ralph.sh model flag passing (now uses bash array)
- Dead reference to empty ralph-template.sh replaced with pointer to canonical ralph.sh

## v1.3 — 2026-03-17

Plan schema standardization, multi-CLI support, loop safety.

- Shared plan format schema (`references/plan-schema.md`) — single source of truth
- plan-to-ralph references plan-schema.md instead of inline format definition
- ralph-prep validates plan schema (frontmatter, task_count, required fields, TODO > 0)
- Multi-CLI prompt support in ralph-template.sh (claude/amp/ollama)
- Revision loop in plan-to-ralph Step 6 — revise until approved
- progress.txt sliding window — keeps last 3 iteration blocks
- Failed iteration logging to ralph-failures.log (no-change / uncommitted-changes)

## v1.2 — 2026-03-17

Guardrails for speed and correctness.

- plan-to-ralph: Speed Rule — DO NOT explore codebase during planning
- ralph-prep: hard-block on missing feedback loops (typechecker/linter/tests)

## v1.1

Version metadata and update mechanism.

- Added version metadata to SKILL.md frontmatter
- Created `/update-ralph` command for pulling latest from GitHub
- Setup uses relative symlinks and auto-discovers SKILL.md directories
- Added subagent rules to AGENTS.md template
- Updated README with workflow diagram

## v1.0

Initial release.

- plan-to-ralph: convert code review findings into Ralph-ready implementation plans
- ralph-prep: prepare environment for autonomous coding loops
- setup-ralph: install typechecker, linter, test runner for a project

# TODOS

> Source: CEO review + Eng review of review-to-plan (v1.2) and ralph-prep (v1.1)
> Created: 2026-03-17
> Mode: SCOPE EXPANSION

## P0 — Safety & Correctness

### ~~1. Delete .bak skill directories~~ DONE
- Deleted `~/.claude/skills/review-to-plan.bak/` and `~/.claude/skills/ralph-prep.bak/`

### ~~2. Hard-block ralph.sh generation without working feedback loops~~ DONE
- Merged Steps 5+6+6b into single Step 5. Hard block on command failure/not-found/timeout. Auto-fix AGENTS.md. ralph-prep bumped to v1.2.

## P1 — Core Improvements

### 3. Shared YAML frontmatter schema for IMPLEMENTATION_PLAN.md
- **What:** Create `references/plan-schema.md` defining the canonical plan format including YAML frontmatter (plan_version, task_count, created, fields_used). Update review-to-plan to write this format. Update ralph-prep to validate against it. Single source of truth — both skills reference the same file.
- **Why:** review-to-plan writes the plan, ralph-prep validates it, Ralph reads it — but there's no shared contract. v1.2 added an "Area" field that v1.1 didn't have. Format drift causes silent failures in Ralph loops.
- **Effort:** S (30 min)
- **Depends on:** Nothing

### 4. Fix multi-CLI prompt in ralph-template.sh
- **What:** In `build_prompt()`, branch on CLI type. For `claude`: keep `@file` syntax. For `amp`/`ollama`: inline file contents via `cat`. Currently the `@IMPLEMENTATION_PLAN.md` syntax only works in Claude Code — amp/ollama receive literal `@file` text instead of file contents.
- **Why:** The template claims multi-CLI support but the prompt silently fails on non-Claude CLIs. Ralph would have no plan to work from.
- **Effort:** S (15 min)
- **Depends on:** Nothing

### 5. Validate TODO count > 0 in ralph-prep
- **What:** In ralph-prep Step 2 (verify plan), count tasks with status `TODO`. If 0: block with "Plan has no remaining TODO tasks. Run /review-to-plan to create new tasks, or check if you need to archive this completed run."
- **Why:** Prevents no-op Ralph runs. If plan is empty or all tasks are DONE (from an unarchived previous run), Ralph launches, finds nothing to do, outputs COMPLETE on first iteration — wasting a cycle.
- **Effort:** XS (5 min)
- **Depends on:** Nothing

### 6. Add explicit revision loop to review-to-plan
- **What:** After presenting the plan in Step 6, add: "Say 'approved' to write files, or describe changes. I'll revise and re-present." Loop until approval or user says stop.
- **Why:** Currently review-to-plan presents the plan and has no instruction for what happens when the user wants changes. The skill dead-ends on revision requests.
- **Effort:** XS (10 min)
- **Depends on:** Nothing

### 7. progress.txt sliding window with delimiter
- **What:** Update ralph-template.sh prompt to tell Ralph: "Start each progress entry with a line containing only `=== ITERATION ===`". After each iteration, ralph.sh counts delimiter lines and keeps only the last 3 blocks (awk-based truncation).
- **Why:** progress.txt grows unboundedly. After 10 iterations it can be 500+ words, eating into the context budget. Per Huntley: progress.txt is a baton pass, not a journal. Git log has the full history.
- **Effort:** XS (10 min)
- **Depends on:** Nothing

### 8. Failed iteration logging
- **What:** In ralph.sh's main loop, record `HEAD_BEFORE=$(git rev-parse HEAD)` before each iteration. After: compare HEAD + check `git status --porcelain`. Three outcomes: (a) HEAD changed → success (already in git), (b) HEAD same + clean tree → log as "no-change iteration" to ralph-failures.log, (c) HEAD same + dirty tree → log as "uncommitted changes". Ensure log directory exists (`touch` or create alongside).
- **Why:** Successful iterations are observable via git log. Failed iterations (where feedback loops broke and no commit happened) leave zero trace. User returns from AFK with no information about what happened during failed iterations.
- **Effort:** S (15 min)
- **Depends on:** Nothing

### 9. Dev repo + symlink workflow + versioned releases
- **What:** Clone ralph-skills to `~/gstack/ralph/` as the development repo. For testing, temporarily symlink `~/.claude/skills/ralph-skills/` → `~/gstack/ralph/`. Restore symlink after testing. Add git tags (vX.Y) + CHANGELOG.md to the GitHub repo.
- **Why:** Currently the live install at `~/.claude/skills/ralph-skills/` IS the development environment. Changes go directly to production. A proper dev workflow separates "working on skills" from "using skills" — dogfooding the review→plan→ship pipeline on the skills themselves.
- **Effort:** M (1 hour)
- **Depends on:** Nothing (but do this before shipping other changes)

## P2 — Ambitious Additions

### 10. Subagent batching for large review inputs
- **What:** If >30 findings are detected in review-to-plan Step 1, spawn parallel subagents to triage batches of ~40-50 findings. Subagent prompt template lives in `references/triage-subagent-prompt.md`. Main context merges results with highest-priority-wins for conflicts, deduplicates, presents unified triage. Include timeout for subagent execution.
- **Why:** Without this, 200+ findings blow the context window and produce a degraded plan. Follows the skill's own principle: "subagents for I/O-heavy recon, main loop for decisions."
- **Effort:** M (45 min)
- **Depends on:** Nothing

### 11. Golden-file eval suite
- **What:** Create `test-fixtures/` with 3-5 review inputs and expected plan outputs. Eval script runs each through the skill and checks: correct priorities, task count, format compliance (per plan-schema.md), word count.
- **Why:** No eval framework exists. When skill changes land (like v1.2's Speed Rule), there's no way to measure whether plan quality improved or degraded. Ironic for skills whose core philosophy is "backpressure is mandatory."
- **Effort:** L (2 hours)
- **Depends on:** TODO 3 (schema makes validation easier)

### 12. Handoff validation in ralph-prep
- **What:** ralph-prep validates that every task in the plan has the fields Ralph's prompt expects (Priority, Status, Description, Acceptance). Catches format drift before Ralph gets a malformed plan.
- **Why:** Delight opportunity — closely related to TODO 3 (schema). Ensures ralph-prep doesn't just count tasks but validates they're well-formed for the loop.
- **Effort:** XS (15 min)
- **Depends on:** TODO 3 (schema defines expected fields)

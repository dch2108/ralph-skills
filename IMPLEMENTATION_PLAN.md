# Implementation Plan

> Source: CEO review + Eng review of review-to-plan and ralph-prep skills (2026-03-17)
> Created: 2026-03-17
> Status: NOT STARTED

## Tasks

### Task 1: Create shared plan format schema
- **Priority:** P1
- **Status:** DONE
- **Area:** references/
- **Description:** Create `references/plan-schema.md` defining the canonical IMPLEMENTATION_PLAN.md format: YAML frontmatter (plan_version, task_count, created, fields_used) and per-task fields (Priority, Status, Area, Files, Description, Acceptance). This is the single source of truth both skills reference.
- **Acceptance:** `references/plan-schema.md` exists with complete format definition.

### Task 2: Update review-to-plan to write schema-compliant plans
- **Priority:** P1
- **Status:** DONE
- **Area:** review-to-plan skill
- **Files:** `review-to-plan/SKILL.md`
- **Description:** Update Step 4 to reference `references/plan-schema.md` for the plan format instead of defining it inline. Output plans must include YAML frontmatter. Remove the inline format definition to avoid duplication.
- **Acceptance:** review-to-plan SKILL.md references plan-schema.md and the example output includes YAML frontmatter.

### Task 3: Update ralph-prep to validate plan schema
- **Priority:** P1
- **Status:** DONE
- **Area:** ralph-prep skill
- **Files:** `ralph-prep/SKILL.md`
- **Description:** In Step 2 (verify plan), add validation: parse YAML frontmatter, verify task_count matches actual tasks, check each task has required fields per plan-schema.md. Also validate TODO count > 0 — block if all tasks are DONE or plan is empty.
- **Acceptance:** ralph-prep Step 2 references plan-schema.md, validates frontmatter, and blocks on zero TODO tasks.

### Task 4: Fix multi-CLI prompt in ralph-template.sh
- **Priority:** P1
- **Status:** TODO
- **Area:** ralph-prep references
- **Files:** `ralph-prep/references/ralph-template.sh`
- **Description:** In `build_prompt()`, branch on CLI type. For `claude`: keep `@file` syntax. For `amp`/`ollama`: inline file contents via `cat $PLAN_FILE` and `cat $PROGRESS_FILE`. The `@file` syntax is Claude Code specific and silently fails on other CLIs.
- **Acceptance:** `build_prompt "amp"` output contains file contents, not literal `@` references.

### Task 5: Add revision loop to review-to-plan
- **Priority:** P1
- **Status:** TODO
- **Area:** review-to-plan skill
- **Files:** `review-to-plan/SKILL.md`
- **Description:** After Step 6 (present for approval), add instruction: "Say 'approved' to write files, or describe changes. Revise and re-present until the user approves or says stop." Currently the skill dead-ends when the user wants changes.
- **Acceptance:** review-to-plan Step 6 contains explicit revision loop instructions.

### Task 6: Add progress.txt sliding window
- **Priority:** P1
- **Status:** TODO
- **Area:** ralph-prep references
- **Files:** `ralph-prep/references/ralph-template.sh`
- **Description:** Update `build_prompt()` to instruct Ralph: "Start each progress entry with a line containing only `=== ITERATION ===`". After each iteration in the main loop, count delimiter lines in progress.txt and keep only the last 3 blocks via awk truncation.
- **Acceptance:** After 5 simulated entries with delimiters, progress.txt contains only the last 3.

### Task 7: Add failed iteration logging
- **Priority:** P1
- **Status:** TODO
- **Area:** ralph-prep references
- **Files:** `ralph-prep/references/ralph-template.sh`
- **Description:** In the main loop, record `HEAD_BEFORE` before each iteration. After, compare HEAD + check `git status --porcelain`. If HEAD unchanged + clean tree: append "no-change" to ralph-failures.log. If HEAD unchanged + dirty tree: append "uncommitted changes". Ensure log file is creatable (touch at start).
- **Acceptance:** ralph.sh contains HEAD comparison logic and writes to ralph-failures.log on non-commit iterations.

### Task 8: Add CHANGELOG.md and tag current release
- **Priority:** P1
- **Status:** TODO
- **Area:** repo root
- **Description:** Create CHANGELOG.md summarizing all versions: v1.0 (initial), v1.1 (version metadata, update skill, subagent rules), v1.2 (Speed Rule in review-to-plan, hard-block feedback in ralph-prep). Tag the current commit as v1.2.
- **Acceptance:** CHANGELOG.md exists and `git tag` shows v1.2.

### Task 9: Add handoff validation to ralph-prep
- **Priority:** P2
- **Status:** TODO
- **Area:** ralph-prep skill
- **Files:** `ralph-prep/SKILL.md`
- **Description:** In Step 2 (after schema validation from Task 3), validate each task has the fields Ralph's prompt expects: Priority, Status, Description, Acceptance. Flag malformed tasks before the loop starts.
- **Acceptance:** ralph-prep Step 2 lists specific required fields and flags tasks missing any of them.

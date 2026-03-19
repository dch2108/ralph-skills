---
name: plan-to-ralph
disable-model-invocation: true
argument-hint: '[input-file or paste text]'
description: >
  Convert code review findings, bug reports, and implementation issues into a
  Ralph-ready PLAN.md. Use when the user says "create a plan from this review",
  "turn these issues into tasks", "prepare tasks for Ralph", "plan fixes from
  code review", "triage these bugs", or provides a list of code problems to
  address. Do NOT use for running the Ralph loop itself (use ralph-prep for that).
---

# Plan to Ralph

Convert input into a `PLAN.md` for the Ralph autonomous coding loop.

## Speed Rule

**Do NOT explore the codebase.** This skill is a text-processing job on the user's input. Ralph's per-task subagents will locate files at execution time. Your job is to describe *what* needs to change and *why*, not *where* in the code it lives.

The only acceptable reads during this skill are:
- Files the user explicitly points you to
- `gh pr view --comments` if the user asks you to pull PR comments
- PLAN.md / BACKLOG.md if they already exist (to avoid clobbering)

## Instructions

### Step 1: Accept input

Accept anything:
- Pasted text or markdown listing issues, bugs, concerns
- GitHub PR review comments (`gh pr view --comments`)
- Output from a code review, security audit, or QA report
- A file the user points to (e.g., `review-notes.md`)
- High-level feature descriptions or product specs

If the input is ambiguous, ask the user to clarify scope. Do NOT guess at issues not explicitly stated.

### Step 2: Decompose into tasks

Break input into small, single-commit tasks. Follow these rules:

- **One logical change per task.** A task can touch multiple files but represents one conceptual unit.
- **Target 8-15 tasks for large changes.** If fewer than 6, verify each task is truly atomic — don't split just to hit a count. A 3-task plan is fine if each task is genuinely one logical change.
- **Each task: 1-2 sentences.** If you need more to describe it, the task is too big — split it.
- **No "and" connecting distinct work.** "Add validation and update the error messages" is two tasks.
- **~150 lines of new code max per task.** If you can envision more, split.
- **Order by dependency, then importance.** If Task B depends on Task A, A comes first.
- **NO PLACEHOLDERS. Full implementations only.** Every task must describe a complete, working change.
- **Remaining items beyond the first tranche go in BACKLOG.md.**

### Step 3: Present PLAN.md for approval

Show the user the full plan. Format:

```markdown
# Plan

- [ ] 1. Short description of one change (1-2 sentences max)
- [ ] 2. Short description of next change
- [ ] 3. Another task with enough context for Ralph to implement it
...
```

Each line must have enough context that an agent with fresh context can implement it without additional instructions. Include the "what" and "why" — Ralph figures out the "where" and "how."

Say "approved" to write files to disk, or describe changes. Revise and re-present until the user approves or says stop.

## Troubleshooting

### Too many items for one plan
Split into `PLAN.md` (first 8-15 tasks) and `BACKLOG.md` (the rest). Run them sequentially.

### Vague input
Ask for specifics: file paths, expected vs. actual behavior, reproduction steps. Do NOT create tasks from descriptions like "the auth is broken" — insist on actionable detail.

### Circular dependencies
Flag the cycle to the user. Suggest breaking it by identifying which change can be made independently first.

### High-level input (feature specs, product plans)
Warn the user: "This input is high-level — each item will need decomposition into concrete tasks. The resulting plan will have more tasks than the original list has items." Then apply aggressive decomposition.

---
name: review-to-plan
metadata:
  version: '1.1'
  author: dch2108
description: >
  Convert code review findings, bug reports, and implementation issues into a
  Ralph-ready implementation plan. Use when the user says "create a plan from
  this review", "turn these issues into tasks", "prepare tasks for Ralph",
  "plan fixes from code review", "triage these bugs", or provides a list of
  code problems to address. Do NOT use for running the Ralph loop itself
  (use ralph-prep for that).
---

# Review to Plan

Convert code review findings into a focused, Ralph-loop-ready implementation plan.

## Philosophy

Follow Geoffrey Huntley's core principles for agentic coding:

- **One logical change per task.** If a task feels too large, break it into subtasks.
- **Prefer many small tasks over few large ones.** Small steps compound into big progress.
- **Quality over speed.** Each task must be completable within a single fresh context window.
- **Keep docs small.** The plan file loads into every iteration — bloat kills the loop.
- **Leave follow-on work for later.** Do NOT try to pack everything into one plan. A manageable first tranche is better than an exhaustive list that rots context.
- **Subagents for reconnaissance, main loop for decisions.** Any work that consumes lots of context tokens without producing code or a decision should be delegated to subagents. The primary loop handles strategy and implementation.

## Instructions

### Step 1: Gather input

Accept code review findings from any source:

- Pasted text or markdown listing issues, bugs, and concerns
- GitHub PR review comments (fetch via `gh pr view --comments` or the user provides them)
- Output from Claude's own code review or security audit
- A file the user points to (e.g., `review-notes.md`)

If the input is ambiguous, ask the user to clarify scope. Do NOT guess at issues not explicitly stated.

### Step 2: Categorize and triage

Sort every finding into one of these buckets:

| Priority | Category | Description |
|----------|----------|-------------|
| P0 | Breaking / blocking | Crashes, data loss, security vulnerabilities, build failures |
| P1 | Correctness | Wrong behavior, logic errors, missing error handling |
| P2 | Quality | Code smells, missing tests, poor naming, tech debt |
| P3 | Enhancement | Nice-to-haves, refactors, style improvements |

Present this triage summary to the user and ask: "Does this prioritization look right? Any items to promote, demote, or drop?"

Do NOT proceed until the user confirms the triage.

### Step 3: Scope the first tranche

Select tasks for the implementation plan. Follow these sizing rules:

- **Maximum 8-12 tasks per plan.** This is one Ralph session's worth of work. Remaining items go into a `BACKLOG.md` file for future runs.
- **Each task must be completable in one commit.** If you cannot describe the change in 2-3 sentences, the task is too big — split it.
- **Prioritize P0 and P1 first.** Only include P2/P3 items if there is room after all higher-priority work is covered.
- **Order by dependency, then priority.** If Task B depends on Task A's output, Task A must come first.

When items remain beyond the first tranche, create `BACKLOG.md` alongside the plan:

```markdown
# Backlog

Items deferred from review on [DATE]. Pick these up in a future Ralph run.

- [ ] P2: [description]
- [ ] P3: [description]
```

### Step 4: Write the implementation plan

Create `IMPLEMENTATION_PLAN.md` in the project root with this exact format:

```markdown
# Implementation Plan

> Source: [describe origin — e.g., "PR #42 review comments", "security audit 2026-03-15"]
> Created: [DATE]
> Status: NOT STARTED

## Tasks

### Task 1: [Short title]
- **Priority:** P0
- **Status:** TODO
- **Files:** `src/auth/login.ts`, `src/auth/login.test.ts`
- **Description:** [2-3 sentences max. What to change and why.]
- **Acceptance:** [One concrete check — e.g., "All auth tests pass", "Login no longer throws on empty input"]
- **Subagent hints:** [Optional. Note if this task benefits from subagent delegation — e.g., "Use subagents to search for all callers of `validateSession()` before modifying its signature"]

### Task 2: [Short title]
- **Priority:** P1
- **Status:** TODO
- **Files:** `src/api/handler.ts`
- **Description:** [2-3 sentences max.]
- **Acceptance:** [One concrete check.]
- **Subagent hints:** [Optional. E.g., "Parallel subagents to update all 6 handler files that import from this module"]
```

Rules for the plan:

- **Task descriptions must be specific and actionable.** Bad: "Fix the auth bug." Good: "Add null check for `user.session` in `login.ts:47` before accessing `.token` property."
- **Always list affected files.** The agent should not have to search the whole repo to find where to work.
- **One acceptance criterion per task.** Keep it binary — pass or fail.
- **Status values:** `TODO`, `IN PROGRESS`, `DONE`, `BLOCKED`
- **Do NOT include implementation details or code snippets.** The agent figures out the how. The plan specifies the what and where.
- **Subagent hints are optional but valuable.** Add them when a task involves searching many files, bulk reads, or parallel independent writes. Omit for straightforward single-file changes. See the subagent delegation rules below.

### Subagent delegation guidance

When writing subagent hints, follow Huntley's rule: if the raw output of a task would be large and mostly noise to the primary loop, it should be delegated. Include hints for these patterns:

| Pattern | Subagent hint example |
|---------|----------------------|
| Searching/reading many files | "Use subagents to find all usages of `deprecatedFn()` across src/" |
| Bulk test/build output | "Delegate test run to 1 subagent; summarize pass/fail only" |
| Studying existing code | "Subagents to study `src/api/` and `src/models/` before changing" |
| Parallel independent writes | "Parallel subagents to update each route handler file independently" |
| Updating tracking files | "Subagent to update IMPLEMENTATION_PLAN.md and progress.txt" |

Do NOT suggest subagents for:
- The core decision of what to implement (that stays in the main loop)
- The actual implementation code for the chosen task
- Validation/builds/tests (limit to 1 subagent — never fan out builds)

### Step 5: Estimate total context budget

After writing the plan, check its size:

1. The plan should be under 2,000 words. If it exceeds this, you have too many tasks or descriptions are too verbose — trim.
2. Combined with `AGENTS.md` and `progress.txt`, the total deterministic context allocation per iteration should stay under ~5,000 tokens. This leaves the majority of the context window for the agent's actual work.

Report the approximate word count to the user.

### Step 6: Present for approval

Show the user:

1. The full `IMPLEMENTATION_PLAN.md`
2. The `BACKLOG.md` (if any items were deferred)
3. Word count of the plan
4. A note: "Run `/ralph-prep` when ready to start the loop."

Do NOT write files to disk until the user approves. Present the plan contents in the conversation first.

## Output Format Example

When presenting to the user, format as:

```
## Triage Summary
- P0 (blocking): 2 items
- P1 (correctness): 3 items  
- P2 (quality): 4 items — 2 deferred to backlog
- P3 (enhancement): 1 item — deferred to backlog

## Implementation Plan (7 tasks)
[full plan content]

## Backlog (3 items deferred)
[backlog content]

Word count: ~1,200 words
Ready for Ralph — run /ralph-prep to begin.
```

## Troubleshooting

### Problem: Too many P0/P1 items to fit in one tranche
Split into two plans: `IMPLEMENTATION_PLAN.md` (first 8-12) and `IMPLEMENTATION_PLAN_2.md` (next batch). Run them sequentially. Do NOT combine into one mega-plan.

### Problem: Review findings are vague
Ask the user for specifics: file paths, expected vs. actual behavior, reproduction steps. Do NOT create tasks from vague descriptions like "the auth is broken" — insist on actionable detail.

### Problem: Tasks have circular dependencies
Flag the cycle to the user. Suggest breaking the cycle by identifying which change can be made independently first, even if it means a temporary workaround.

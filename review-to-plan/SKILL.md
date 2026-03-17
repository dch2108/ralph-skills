---
name: review-to-plan
metadata:
  version: '1.3'
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

## Speed Rule

**Do NOT explore the codebase.** This skill is a text-processing job on the user's input — not a code archaeology expedition. Ralph's per-task subagents will locate files and line numbers at execution time. Your job is to describe *what* needs to change and *why*, not *where* exactly in the code it lives.

The only acceptable reads during this skill are:
- Files the user explicitly points you to (e.g., "see review-notes.md")
- `gh pr view` if the user asks you to pull PR comments
- IMPLEMENTATION_PLAN.md / BACKLOG.md if they already exist (to avoid clobbering)

If a review finding already includes file paths or line numbers, include them. If it doesn't, do NOT go searching — write a descriptive enough task that Ralph can find the right place with a simple grep.

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

Create `IMPLEMENTATION_PLAN.md` in the project root following the format defined in `references/plan-schema.md`.

Key points:

- The plan **must** start with YAML frontmatter (`plan_version`, `task_count`, `created`, `fields_used`).
- `task_count` in frontmatter must match the actual number of `### Task N:` headings.
- See `references/plan-schema.md` for the full document structure, per-task fields, and rules.

Additional guidance for this skill:

- **Task descriptions must be specific and actionable.** Bad: "Fix the auth bug." Good: "Add null check on `user.session` before accessing `.token` property — currently throws TypeError when session expires."
- **Include file paths only when already known.** If the review finding mentions a file, include it. If not, describe the area/module and let Ralph locate the files. Do NOT explore the codebase to fill in file paths.
- **Ralph finds files, you describe intent.** A well-written description like "the counter module double-counts when frames overlap" is more useful than a stale line number that shifts after the first commit.

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
[full plan content, starting with YAML frontmatter per references/plan-schema.md]

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

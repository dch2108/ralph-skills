# Plan Schema

> Canonical format for IMPLEMENTATION_PLAN.md files.
> Both `plan-to-ralph` and `ralph-prep` reference this file as the single source of truth.

## YAML Frontmatter

Every plan starts with YAML frontmatter followed by the markdown body:

```yaml
---
plan_version: "1.0"
task_count: 9
created: "2026-03-17"
fields_used: [Priority, Status, Area, Files, Description, Acceptance]
---
```

| Field | Required | Description |
|-------|----------|-------------|
| `plan_version` | Yes | Schema version. Currently `"1.0"`. |
| `task_count` | Yes | Total number of tasks in the plan. Must match actual `### Task N:` count. |
| `created` | Yes | ISO date the plan was created. |
| `fields_used` | Yes | List of per-task fields present in this plan. |

## Document Structure

After the frontmatter:

```markdown
# Implementation Plan

> Source: [describe origin — e.g., "PR #42 review comments", "security audit 2026-03-15"]
> Created: [DATE]
> Status: NOT STARTED | IN PROGRESS | COMPLETE

## Tasks

### Task 1: [Short title]
- **Priority:** P0
- **Status:** TODO
- **Area:** [module/layer name — e.g., "auth module", "API handlers", "database layer"]
- **Files:** [Only if known from the review input. Otherwise omit this line entirely.]
- **Description:** [2-3 sentences max. What to change and why. Be specific enough that a grep can find the right code.]
- **Acceptance:** [One concrete check — e.g., "All auth tests pass", "Login no longer throws on empty input"]
```

## Per-Task Fields

| Field | Required | Values / Notes |
|-------|----------|----------------|
| **Priority** | Yes | `P0` (critical) > `P1` (high) > `P2` (medium) > `P3` (low) |
| **Status** | Yes | `TODO`, `IN PROGRESS`, `DONE`, `BLOCKED` |
| **Area** | Yes | Module or layer name for grouping |
| **Files** | No | Include only when known from review input. Omit rather than guess. |
| **Description** | Yes | 2-3 sentences. Specific and actionable. No code snippets. |
| **Acceptance** | Yes | One binary pass/fail check. |

## Rules

1. Task descriptions must be specific and actionable.
2. Include file paths only when already known from review input.
3. One acceptance criterion per task — keep it binary.
4. Do NOT include implementation details or code snippets. The agent figures out the how; the plan specifies the what and why.
5. Plan should be under 2,000 words total.
6. Task numbering is sequential: `Task 1`, `Task 2`, etc.
7. `task_count` in frontmatter must equal the actual number of `### Task N:` headings.

## Machine-Readable Patterns

These patterns are used by `ralph.sh` and `ralph-prep` for plan parsing. The leading `- ` (list-item prefix) is part of the format — patterns must account for it.

- Count TODO tasks: `grep -c '\*\*Status:\*\* TODO' IMPLEMENTATION_PLAN.md`
- Count DONE tasks: `grep -c '\*\*Status:\*\* DONE' IMPLEMENTATION_PLAN.md`
- Count IN PROGRESS tasks: `grep -c '\*\*Status:\*\* IN PROGRESS' IMPLEMENTATION_PLAN.md`
- Mark task done: change `**Status:** TODO` → `**Status:** DONE`
- Extract task titles: `grep '^### Task' IMPLEMENTATION_PLAN.md`

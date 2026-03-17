# AGENTS.md

## Project Type
Skill markdown repo (not a code project). No build/test/typecheck/lint tooling.

## Feedback Loops (HITL mode — user is the backpressure)
No automated feedback loops. Run in HITL mode only (1 iteration at a time).
Do NOT run AFK (multi-iteration) without the user watching.

## Conventions
- One logical change per commit
- Bump `metadata.version` in SKILL.md frontmatter when modifying a skill
- Keep SKILL.md files under 800 words where possible
- Reference files go in `references/` directories within each skill

## Subagent Rules
- Before making changes, search the codebase using parallel subagents (do not assume something is not implemented)
- Delegate file reads to subagents — keep raw file contents out of primary context
- Use subagents to study existing SKILL.md files before modifying them
- Parallel subagents OK for independent file writes
- Use a subagent to update IMPLEMENTATION_PLAN.md and progress.txt after each task
- Do NOT delegate: task selection, implementation decisions, or the core edit itself

# Changelog

## v1.3 — 2026-03-17

Plan schema standardization, multi-CLI support, loop safety.

- Shared plan format schema (`references/plan-schema.md`) — single source of truth
- review-to-plan references plan-schema.md instead of inline format definition
- ralph-prep validates plan schema (frontmatter, task_count, required fields, TODO > 0)
- Multi-CLI prompt support in ralph-template.sh (claude/amp/ollama)
- Revision loop in review-to-plan Step 6 — revise until approved
- progress.txt sliding window — keeps last 3 iteration blocks
- Failed iteration logging to ralph-failures.log (no-change / uncommitted-changes)

## v1.2 — 2026-03-17

Guardrails for speed and correctness.

- review-to-plan: Speed Rule — DO NOT explore codebase during planning
- ralph-prep: hard-block on missing feedback loops (typechecker/linter/tests)

## v1.1

Version metadata and update mechanism.

- Added version metadata to SKILL.md frontmatter
- Created `/update-ralph-skills` command for pulling latest from GitHub
- Setup uses relative symlinks and auto-discovers SKILL.md directories
- Added subagent rules to AGENTS.md template
- Updated README with workflow diagram

## v1.0

Initial release.

- review-to-plan: convert code review findings into Ralph-ready implementation plans
- ralph-prep: prepare environment for autonomous coding loops
- setup-feedback: install typechecker, linter, test runner for a project

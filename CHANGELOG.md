# Changelog

## v1.4 — 2026-03-17

Field-testing fixes: 10 issues from real-world Ralph loop usage.

### Changed
- ralph.sh is now the only valid loop script — ralph-prep archives all `.py`/`.js`/`.ts` variants unconditionally
- Stricter task sizing rules in plan-to-ralph aligned with Huntley methodology (split on "and", ~150 line rule, ~5 test rule)
- ralph.sh streams output in real-time via tee (no more capture-then-echo)
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

# ralph-skills

**ralph-skills turns Claude Code into an autonomous coding machine that works while you sleep.**

Four skills for running [Ralph Wiggum](https://ghuntley.com/ralph/) autonomous coding loops in [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Plan your work, validate the environment, and let the agent ship tasks one at a time — each in a fresh context window, with feedback loops as backpressure.

Based on [Geoffrey Huntley's methodology](https://ghuntley.com/ralph/).

### The workflow

```
/plan-to-ralph           <- turn review findings into PLAN.md
/setup-ralph             <- one-time: install project feedback tooling
/ralph-prep              <- validate everything, copy ralph.sh
./ralph.sh               <- HITL: watch one iteration (default)
./ralph.sh 10            <- AFK: let it run
```

Each iteration picks one task, implements it, runs all feedback loops, commits, marks it done, and stops. Fresh context every time. `PLAN.md` and a sliding window of `progress.txt` are the only state that carries forward.

### Skills

| Skill | What it does |
|-------|--------------|
| `/plan-to-ralph` | Convert review findings, bug reports, or feature goals into a `PLAN.md` — a numbered checkbox list of small, single-commit tasks. |
| `/ralph-prep` | Validate environment: git repo, plan exists, feedback loops work. Copies `ralph.sh` from template. |
| `/setup-ralph` | Install feedback loop tooling (typechecker, linter, test runner) for a project. One-time setup. |
| `/update-ralph` | Pull latest from GitHub, re-run setup, report version changes. |

## Install

**Requirements:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Git](https://git-scm.com/).

### Step 1: Install on your machine

Open Claude Code and paste this:

> Install ralph-skills: run `git clone https://github.com/dch2108/ralph-skills.git ~/.claude/skills/ralph-skills && cd ~/.claude/skills/ralph-skills && ./setup` then add a "ralph-skills" section to CLAUDE.md that lists the available skills: /plan-to-ralph, /ralph-prep, /setup-ralph, /update-ralph.

### Step 2: Add to your repo so teammates get it (optional)

> Add ralph-skills to this project: run `cp -Rf ~/.claude/skills/ralph-skills .claude/skills/ralph-skills && rm -rf .claude/skills/ralph-skills/.git && cd .claude/skills/ralph-skills && ./setup` then add a "ralph-skills" section to this project's CLAUDE.md that lists the available skills: /plan-to-ralph, /ralph-prep, /setup-ralph, /update-ralph.

### What gets installed

- Skill files (Markdown prompts) in `~/.claude/skills/ralph-skills/`
- Symlinks at `~/.claude/skills/plan-to-ralph`, `~/.claude/skills/ralph-prep`, etc.
- Reference files: plan format spec (`references/plan-schema.md`), loop script template (`ralph-prep/references/ralph-template.sh`)

Everything lives inside `.claude/`. Nothing touches your PATH or runs in the background.

## Update

```
/update-ralph
```

Or manually: `cd ~/.claude/skills/ralph-skills && git pull origin main && ./setup`

## How it works

### `/plan-to-ralph`

Hand it anything: code review findings, bug reports, feature descriptions, PR comments. It decomposes the input into small, single-commit tasks and writes `PLAN.md`:

```markdown
# Plan

- [ ] 1. Add null check on user.session before accessing .token — currently throws TypeError when session expires
- [ ] 2. Extract rate limiting logic from AuthController into a shared concern
- [ ] 3. Add integration test for the password reset flow
...
```

Each task is 1-2 sentences — enough context for a fresh agent to implement it. Order matters: dependencies first.

### `/ralph-prep`

Three checks + script copy. Completes in 30 seconds:

1. **Git repo** — must be a git repo with (ideally) clean working tree
2. **Plan exists** — `PLAN.md` must have unchecked items
3. **Feedback loops work** — runs each command in AGENTS.md with a timeout

Then copies `ralph.sh` from the template. If any check fails, it tells you exactly what to fix.

### `/setup-ralph`

Detects your project stack and installs feedback tooling: typechecker, linter, test runner, build command. Configures them in AGENTS.md. Run this once per project.

### The loop script (`ralph.sh`)

Key features:

- **One task per iteration.** `extract_next_task()` feeds the agent ONLY the first unchecked item from PLAN.md. The agent literally cannot see other tasks.
- **Short prompt.** ~6 lines. AGENTS.md carries project-specific instructions (feedback loops, subagent rules, conventions).
- **Live streaming.** Uses `script` (pseudo-tty) so you see output in real time during HITL mode.
- **Remaining-tasks summary.** The prompt shows all unchecked tasks so the agent has situational awareness of the full plan, then designates exactly one to work on.
- **Multi-CLI.** Works with Claude Code, Amp, and Ollama. Auto-detects or set `CLI=` env var.
- **Delta enforcement.** After each iteration, verifies exactly one task was completed. Logs violations.
- **Auto-tagging.** When an iteration completes cleanly (delta == 1, new commit), the script runs all feedback loop commands from AGENTS.md. If they all pass, it creates an incremental semver patch tag (e.g. `v0.0.1`, `v0.0.2`, …). No tags yet? Starts at `v0.0.1`.
- **Sliding window.** `progress.txt` keeps only the last 3 iteration blocks.
- **Failure logging.** No-commit iterations get logged to `ralph-failures.log` with timestamps.

#### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLI` | auto-detect | Which CLI to use: `claude`, `amp`, or `ollama` |
| `MODEL` | *(empty — uses CLI default)* | Model override. Passed as `--model` for Claude Code, or as the model name for Ollama. Example: `MODEL=opus ./ralph.sh 5` |
| `OLLAMA_MODEL` | `llama3.3` | Default model for Ollama (overridden by `MODEL`) |
| `CLAUDE_FLAGS` | *(empty)* | Extra flags passed to the `claude` CLI |

## Principles

From [Huntley's methodology](https://ghuntley.com/ralph/):

- **One task per iteration.** Fresh context window each time. The plan is the coordination mechanism.
- **AGENTS.md carries the weight.** Feedback loops, subagent rules, conventions — all in AGENTS.md. The prompt stays short.
- **Backpressure is mandatory.** Tests, types, lint — the agent doesn't commit if they fail.
- **Trust the loop.** Ralph is deterministically bad in an undeterministic world. Tune by watching, adjusting prompts, and running more loops.
- **Subagents for recon, main loop for decisions.** File searching and test runs get delegated; implementation stays in the primary context.
- **Plans describe intent, not location.** "The counter module double-counts when frames overlap" is better than a stale line number.

### Prompt guardrails

The loop prompt includes these rules so Ralph stays disciplined across iterations:

- **Search before assuming.** Use subagents to search the codebase before making changes — don't assume functionality is missing.
- **Subagent budget.** One subagent for build/test runs. Parallel subagents are fine for file searches and reads.
- **No placeholders.** Implement completely. No stubs, placeholders, or minimal implementations.
- **BACKLOG.md bug capture.** If Ralph discovers bugs unrelated to the current task, it documents them in `BACKLOG.md` via a subagent instead of fixing them now.
- **AGENTS.md self-improvement.** If Ralph learns something new about how to build, test, or run the project, it updates `AGENTS.md` via a subagent — commands only, no status updates.

## Troubleshooting

**Skill not showing up?** Run `cd ~/.claude/skills/ralph-skills && ./setup` to rebuild symlinks.

**ralph-prep blocks on feedback loops?** Run `/setup-ralph` to install missing tooling.

**ralph.sh exits immediately?** Check that `PLAN.md` has unchecked items (`- [ ]`).

**Nothing happened AFK?** Check `ralph-failures.log` for iteration-level diagnostics.

## License

MIT

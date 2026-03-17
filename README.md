# ralph-skills

**ralph-skills turns Claude Code into an autonomous coding machine that works while you sleep.**

Four skills for running [Ralph Wiggum](https://ghuntley.com/agent/) autonomous coding loops in [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Plan your work from review findings, validate the environment, generate the loop script, and let the agent ship tasks one at a time — each in a fresh context window, with feedback loops as backpressure.

Based on [Geoffrey Huntley's methodology](https://www.youtube.com/watch?v=4Nna09dG_c0).

### Without ralph-skills

- You manually translate code review comments into tasks, losing context and priority
- You start an agentic loop without checking if tests, linter, and typechecker actually work — the agent commits broken code silently
- The agent burns context reading dozens of files directly instead of using subagents for recon
- progress.txt grows unboundedly until it eats half the context window
- Failed iterations leave no trace — you come back from AFK with no idea what went wrong

### With ralph-skills

| Skill | What it does |
|-------|--------------|
| `/review-to-plan` | Convert code review findings, bug reports, or issues into a structured IMPLEMENTATION_PLAN.md with priorities, acceptance criteria, and context budget estimates. |
| `/ralph-prep` | Validate everything before the loop starts: plan schema, AGENTS.md, feedback loops, previous run artifacts. Generates a tuned `ralph.sh` script. |
| `/setup-feedback` | Install and configure feedback loop tooling (typechecker, linter, test runner, build command) for a project. One-time setup. |
| `/update-ralph-skills` | Pull latest from GitHub, re-run setup, report version changes. |

## The workflow

```
/review-to-plan          ← turn review findings into IMPLEMENTATION_PLAN.md
/setup-feedback          ← one-time: install project feedback tooling
/ralph-prep              ← validate everything, generate ralph.sh
./ralph.sh 1             ← HITL: watch one iteration
./ralph.sh 10            ← AFK: let it run
```

Each iteration picks one task, implements it, runs all feedback loops, commits, updates the plan, and moves on. Fresh context every time. The plan and a sliding window of progress.txt are the only state that carries forward.

## Install

**Requirements:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Git](https://git-scm.com/).

### Step 1: Install on your machine

Open Claude Code and paste this. Claude will do the rest.

> Install ralph-skills: run `git clone https://github.com/dch2108/ralph-skills.git ~/.claude/skills/ralph-skills && cd ~/.claude/skills/ralph-skills && ./setup` then add a "ralph-skills" section to CLAUDE.md that lists the available skills: /review-to-plan, /ralph-prep, /setup-feedback, /update-ralph-skills.

### Step 2: Add to your repo so teammates get it (optional)

> Add ralph-skills to this project: run `cp -Rf ~/.claude/skills/ralph-skills .claude/skills/ralph-skills && rm -rf .claude/skills/ralph-skills/.git && cd .claude/skills/ralph-skills && ./setup` then add a "ralph-skills" section to this project's CLAUDE.md that lists the available skills: /review-to-plan, /ralph-prep, /setup-feedback, /update-ralph-skills.

Real files get committed to your repo (not a submodule), so `git clone` just works. Teammates just need to run `cd .claude/skills/ralph-skills && ./setup` once to create the symlinks.

### What gets installed

- Skill files (Markdown prompts) in `~/.claude/skills/ralph-skills/`
- Symlinks at `~/.claude/skills/review-to-plan`, `~/.claude/skills/ralph-prep`, etc. pointing into the ralph-skills directory
- Reference files: plan schema (`references/plan-schema.md`), loop script template (`ralph-prep/references/ralph-template.sh`)

Everything lives inside `.claude/`. Nothing touches your PATH or runs in the background.

## Update

Open Claude Code and paste this:

> Update ralph-skills: run `cd ~/.claude/skills/ralph-skills && git pull origin main && ./setup` then report which skill versions changed.

Or use the slash command:

```
/update-ralph-skills
```

## How it works

### `/review-to-plan`

You hand it code review findings, bug reports, a list of issues — any unstructured input describing problems to fix. It triages them by priority, groups related items, estimates a context budget, and writes a structured `IMPLEMENTATION_PLAN.md` that Ralph can execute.

The plan follows a shared schema (`references/plan-schema.md`) with YAML frontmatter and per-task fields: Priority, Status, Area, Description, Acceptance. One acceptance criterion per task — binary pass/fail. No implementation details. Ralph figures out the how; the plan specifies the what and why.

Items that are too large, too speculative, or too low-priority get deferred to `BACKLOG.md` instead of bloating the plan.

### `/ralph-prep`

This is the safety gate between "I have a plan" and "the agent is running autonomously."

It validates everything:
- **Plan schema:** YAML frontmatter, task count, required fields, TODO count > 0
- **AGENTS.md:** feedback loop commands exist and actually work (not just listed — executed with timeouts)
- **Previous runs:** archives old progress.txt and ralph-failures.log so the new run starts clean
- **Loop script:** generates a tuned `ralph.sh` with CLI detection, Docker support, subagent instructions, progress sliding window, and failed iteration logging

If feedback loops don't work, it blocks. Ralph without backpressure produces broken code silently. That is the one thing this workflow will not let you do.

### `/setup-feedback`

Detects your project stack and installs the right feedback tooling: TypeScript typechecker, ESLint/Biome, Vitest/Jest, build commands. Configures them in AGENTS.md so ralph-prep can validate them.

Run this once per project. After that, `/ralph-prep` handles validation on every loop run.

### The loop script (`ralph.sh`)

Generated by `/ralph-prep`, customized for your project. Key features:

- **Multi-CLI support:** Works with Claude Code, Amp, and Ollama. Auto-detects which is available.
- **Docker sandbox:** Uses Docker isolation for multi-iteration AFK runs when available.
- **Subagent rules:** Recon and test runs go to subagents. Implementation stays in the main context.
- **Sliding window:** progress.txt keeps only the last 3 iteration blocks. Git log has the full history.
- **Failure logging:** If an iteration produces no commit, it logs why (no changes vs. uncommitted dirty tree) to `ralph-failures.log`.
- **Completion detection:** When all tasks are DONE, the loop exits cleanly.

## Principles

Core ideas from Huntley's methodology:

- **One task per iteration.** Fresh context window each time. The plan is the coordination mechanism, not shared memory.
- **Small commits.** If a task can't be described in 2-3 sentences, split it.
- **Backpressure is mandatory.** Tests, types, lint — the agent doesn't commit if they fail.
- **Subagents for recon, main loop for decisions.** File searching and test runs get delegated; implementation stays in the primary context window.
- **Keep docs small.** AGENTS.md + plan + progress.txt should stay under ~5,000 tokens combined.
- **Plans describe intent, not implementation.** "The counter module double-counts when frames overlap" is more useful than a stale line number that shifts after the first commit.

## Troubleshooting

**Skill not showing up in Claude Code?**
Run `cd ~/.claude/skills/ralph-skills && ./setup`. This rebuilds symlinks so Claude can discover the skills.

**ralph-prep blocks on feedback loops?**
Run `/setup-feedback` to install the missing tooling, then re-run `/ralph-prep`.

**ralph.sh exits immediately?**
Check that `IMPLEMENTATION_PLAN.md` has at least one task with `Status: TODO`. If all tasks are DONE, create a new plan with `/review-to-plan`.

**Coming back from AFK and nothing happened?**
Check `ralph-failures.log` — it records every iteration that didn't produce a commit, with timestamps and reasons.

## License

MIT

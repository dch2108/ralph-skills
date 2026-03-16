# ralph-skills

Three Claude Code skills for running [Ralph Wiggum](https://github.com/snarktank/ralph) autonomous coding loops, following [Geoffrey Huntley's](https://ghuntley.com/agent/) methodology.

## Install

Paste this into Claude Code:

```
Install ralph-skills: run `git clone https://github.com/dch2108/ralph-skills.git ~/.claude/skills/ralph-skills && cd ~/.claude/skills/ralph-skills && ./setup` then list the available skills: /review-to-plan, /ralph-prep, /setup-feedback, /update-ralph-skills.
```

## Skills

| Skill | What it does | When to run |
|-------|-------------|-------------|
| `/setup-feedback` | Installs typechecker, linter, test runner, build command | Once per project |
| `/review-to-plan` | Converts code review findings into an implementation plan | Once per review |
| `/ralph-prep` | Archives old runs, validates AGENTS.md, smoke-tests feedback loops, generates loop script | Once per loop run |
| `/update-ralph-skills` | Pulls latest from GitHub, re-runs setup, reports version changes | When you want to update |

## Workflow

```
/setup-feedback          ← one-time: install project feedback tooling
/review-to-plan          ← create IMPLEMENTATION_PLAN.md from review findings
/ralph-prep              ← validate everything, get ready to loop
./ralph.sh 1             ← HITL: watch one iteration
./ralph.sh 10            ← AFK: let it run
```

## Principles

Based on Huntley's core ideas:

- **One task per iteration.** Fresh context window each time.
- **Small commits.** If a task can't be described in 2-3 sentences, split it.
- **Backpressure is mandatory.** Tests, types, lint — the agent doesn't commit if they fail.
- **Subagents for recon, main loop for decisions.** Searching and reading files gets delegated; implementation stays in the primary context.
- **Keep docs small.** AGENTS.md + plan + progress.txt should stay under ~5,000 tokens combined.

## Project install (for teammates)

```bash
cp -Rf ~/.claude/skills/ralph-skills .claude/skills/ralph-skills
rm -rf .claude/skills/ralph-skills/.git
cd .claude/skills/ralph-skills && ./setup
```

## Update

From inside Claude Code:

```
/update-ralph-skills
```

Or manually:

```bash
cd ~/.claude/skills/ralph-skills && git pull && ./setup
```

## License

MIT

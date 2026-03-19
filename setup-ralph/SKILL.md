---
name: setup-ralph
metadata:
  version: '2.3'
  author: dch2108
description: >
  Install and configure feedback loop tooling (typechecker, linter, test runner,
  build command) for a project. Run once per project to set up the backpressure
  infrastructure that Ralph and other agentic loops depend on. Use when the user
  says "setup feedback loops", "install typechecker", "install linter",
  "configure tests", "setup-ralph", "my project has no linter", or when
  ralph-prep reports missing feedback tooling. Do NOT use for running or
  prepping Ralph loops (use ralph-prep for that).
---

# Setup Feedback

One-time installation and configuration of feedback loop tooling for a project. This is project infrastructure — run it once, commit the config, and every future Ralph run benefits.

## Why this matters

Agentic coding loops (Ralph, or any autonomous agent) need backpressure to stay on track. Without a typechecker, linter, and test runner, the agent will silently produce broken code that compounds across iterations. Huntley calls this non-negotiable: "Ralph only works if there are feedback loops."

## Instructions

### Step 1: Detect the project stack

Identify the primary language/framework:

| Indicator | Stack |
|-----------|-------|
| `package.json` | Node.js / TypeScript |
| `requirements.txt`, `pyproject.toml`, `setup.py`, `Pipfile` | Python |
| `Cargo.toml` | Rust |
| `go.mod` | Go |

If multiple indicators exist (e.g., a Python backend + Node frontend), ask the user which stack is primary or whether to set up both.

### Step 2: Audit what already exists

For the detected stack, check each feedback mechanism:

| Mechanism | What to check | Status |
|-----------|--------------|--------|
| Typechecker | Config file + command runs | Exists / Missing / Broken |
| Linter | Config file + command runs | Exists / Missing / Broken |
| Test runner | Config/script + command runs | Exists / Missing / Broken |
| Build | Script/command + runs clean | Exists / Missing / Broken |

**Stack-specific detection:**

**Node.js / TypeScript:**
- Typechecker: `tsconfig.json` exists AND `typescript` in devDependencies AND `npx tsc --noEmit` runs
- Linter: `eslint.config.*` or `.eslintrc*` exists AND `npx eslint .` runs
- Tests: `test` script in `package.json` AND it runs
- Build: `build` script in `package.json` AND it runs

**Python:**
- Typechecker: `mypy.ini` or `pyrightconfig.json` or `[tool.mypy]` in pyproject.toml AND `mypy .` or `pyright` runs
- Linter: `ruff.toml` or `[tool.ruff]` in pyproject.toml AND `ruff check .` runs
- Tests: `pytest.ini` or `[tool.pytest]` in pyproject.toml AND `pytest` runs
- Build: `python -m build` or `make` or equivalent runs

**Rust:**
- Typechecker: Built-in (`cargo check`)
- Linter: `cargo clippy` (may need `rustup component add clippy`)
- Tests: Built-in (`cargo test`)
- Build: Built-in (`cargo build`)

**Go:**
- Typechecker: Built-in (`go vet ./...`)
- Linter: `golangci-lint` installed AND `.golangci.yml` exists
- Tests: Built-in (`go test ./...`)
- Build: Built-in (`go build ./...`)

Present the audit results and identify what's missing.

### Step 3: Propose installations

For each missing mechanism, present what will be installed. Ask the user to confirm before proceeding.

**Node.js / TypeScript — recommended defaults:**

| Missing | What to install | Why this choice |
|---------|----------------|-----------------|
| TypeScript | `npm install -D typescript` + `npx tsc --init --strict` | Strict mode catches more bugs — that's the point |
| Linter | `npm init @eslint/config@latest` | Latest flat config format |
| Test runner | `npm install -D vitest` + add `"test": "vitest run"` to scripts | Fast, zero-config for most projects |
| Build script | Add `"build": "tsc"` or `"build": "tsc && <bundler>"` to scripts | Depends on whether project uses a bundler |
| Typecheck script | Add `"typecheck": "tsc --noEmit"` to scripts | Separates type checking from build output |

**Python — recommended defaults:**

| Missing | What to install | Why this choice |
|---------|----------------|-----------------|
| Type checker | `pip install mypy` + create `mypy.ini` with `strict = True` | mypy is the standard; pyright is faster but less common |
| Linter | `pip install ruff` + create `ruff.toml` | Ruff replaces flake8+isort+black, extremely fast |
| Test runner | `pip install pytest` | De facto standard |

**Rust — recommended defaults:**

| Missing | What to install | Why this choice |
|---------|----------------|-----------------|
| Clippy | `rustup component add clippy` | Built into the toolchain |

**Go — recommended defaults:**

| Missing | What to install | Why this choice |
|---------|----------------|-----------------|
| Linter | `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest` + create `.golangci.yml` | Standard Go linter aggregator |

Do NOT install anything without user confirmation.

### Step 4: Install and verify

For each confirmed installation:

1. Run the install command.
2. Create any necessary config files.
3. Run the tool once to verify it works.
4. If the tool reports existing issues (e.g., TypeScript strict mode flags current code), note them but do NOT fix them now. Report: "TypeScript found 14 type errors in existing code. These are pre-existing — you may want to address them before running Ralph, or let Ralph fix them as a task."

### Step 5: Add package.json scripts (Node.js projects)

For Node.js projects, ensure `package.json` has scripts for every feedback mechanism. Add any that are missing:

```json
{
  "scripts": {
    "build": "tsc",
    "typecheck": "tsc --noEmit",
    "lint": "eslint .",
    "test": "vitest run"
  }
}
```

This matters because AGENTS.md references these scripts (e.g., `npm run typecheck`), and the Ralph loop prompt tells the agent to "run ALL feedback loops listed in AGENTS.md." Consistent script names make everything composable.

### Step 6: Update AGENTS.md

Add or update the `## Feedback Loops` section in AGENTS.md with the exact commands that now work:

```markdown
## Feedback Loops (run before every commit)
1. Typecheck: `npm run typecheck`
2. Tests: `npm test`
3. Lint: `npm run lint`
4. Build: `npm run build`

Do NOT commit if any of these fail. Fix the failure first.
Delegate test/build output to 1 subagent — return only pass/fail + failure names and errors.
```

Replace the example commands with the actual commands for this project.

### Step 7: Commit the tooling config

Commit all new config files and package.json changes:

```
git add tsconfig.json eslint.config.mjs package.json AGENTS.md [etc.]
git commit -m "chore: configure feedback loop tooling (typecheck, lint, test, build)"
```

This is project infrastructure — it belongs in version control.

### Step 8: Report

Present a summary:

```
## Feedback Loops — Configured

| Mechanism | Command | Status |
|-----------|---------|--------|
| Typecheck | npm run typecheck | ✓ installed, 14 pre-existing errors |
| Linter | npm run lint | ✓ installed, clean |
| Tests | npm test | ✓ already existed, 42 passing |
| Build | npm run build | ✓ already existed, success |

AGENTS.md updated with feedback commands.
Config committed to git.

Next: Run /plan-to-ralph to create a task list, then /ralph-prep to start the loop.
```

## Troubleshooting

### Problem: TypeScript strict mode produces hundreds of errors
This is expected for projects that weren't written with strict mode. Two options:
1. Start with a relaxed config (`strict: false`, enable individual checks incrementally) — pragmatic but weaker backpressure
2. Keep strict mode and add fixing type errors as Ralph tasks — stronger backpressure once clean

Ask the user which approach they prefer.

### Problem: Project uses an unusual build system
If the project doesn't use standard tooling (e.g., custom Makefiles, Bazel, Nix), ask the user for the exact commands. The skill can't auto-detect everything — but AGENTS.md just needs the commands to work.

### Problem: Multiple languages in one repo
Set up feedback for each language separately. AGENTS.md can list multiple command sets:
```markdown
## Feedback Loops
### Backend (Python)
1. Typecheck: `mypy src/`
2. Tests: `pytest`
3. Lint: `ruff check src/`

### Frontend (TypeScript)
1. Typecheck: `npm run typecheck`
2. Tests: `npm test`
3. Lint: `npm run lint`
```

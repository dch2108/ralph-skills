#!/usr/bin/env bash
# ralph.sh — Autonomous coding loop (Ralph Wiggum pattern)
# Based on Geoffrey Huntley's methodology
#
# Usage:
#   ./ralph.sh [iterations]     # Default: 10 iterations
#   ./ralph.sh 1                # Single HITL iteration (watch mode)
#   ./ralph.sh 30               # AFK batch run
#
# Prerequisites:
#   - IMPLEMENTATION_PLAN.md in project root
#   - AGENTS.md with feedback loop commands
#   - Git repo with clean working tree
#
# Supports: claude, amp, ollama (auto-detected or set CLI= env var)

set -euo pipefail

MAX_ITERATIONS="${1:-10}"
PLAN_FILE="IMPLEMENTATION_PLAN.md"
PROGRESS_FILE="progress.txt"
COMPLETE_SIGNAL="<promise>COMPLETE</promise>"

# --- Detect CLI tool ---
detect_cli() {
  if [ -n "${CLI:-}" ]; then
    echo "$CLI"
    return
  fi
  if command -v claude &>/dev/null; then
    echo "claude"
  elif command -v amp &>/dev/null; then
    echo "amp"
  elif command -v ollama &>/dev/null; then
    echo "ollama"
  else
    echo "ERROR: No supported CLI found (claude, amp, ollama). Set CLI= env var." >&2
    exit 1
  fi
}

# --- Detect Docker ---
detect_docker() {
  if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    echo "true"
  else
    echo "false"
  fi
}

# --- Build the prompt ---
build_prompt() {
  local cli="${1:-claude}"

  # File injection: @file syntax is Claude Code-specific.
  # Other CLIs need file contents inlined.
  local file_header
  if [ "$cli" = "claude" ]; then
    file_header="@${PLAN_FILE} @${PROGRESS_FILE}"
  else
    file_header="$(cat <<FILES
--- BEGIN ${PLAN_FILE} ---
$(cat "$PLAN_FILE")
--- END ${PLAN_FILE} ---

--- BEGIN ${PROGRESS_FILE} ---
$(cat "$PROGRESS_FILE")
--- END ${PROGRESS_FILE} ---
FILES
)"
  fi

  cat <<PROMPT
${file_header}

1. Study the IMPLEMENTATION_PLAN.md. Pick the single most important TODO task.
   Prioritize: blocked dependencies first, then highest priority (P0 > P1 > P2).

2. Before making changes, search the codebase using parallel subagents.
   Do NOT assume something is not already implemented.
   Use subagents to study relevant source files — do NOT read dozens of files
   directly into this context. Subagents return summaries; raw rg output stays
   out of the primary window.

3. Implement ONLY that one task in the main context. Keep the change small
   and focused. The implementation decision and the code itself stay here —
   do NOT delegate the actual fix to a subagent.

4. Run ALL feedback loops listed in AGENTS.md before committing.
   Delegate test/build runs to exactly 1 subagent — return only pass/fail
   and failure names/errors. Do NOT fan out multiple build subagents.
   Do NOT commit if any check fails. Fix failures first.

5. When all checks pass, make a git commit with a descriptive message
   referencing the task title.

6. Use a subagent to update IMPLEMENTATION_PLAN.md (set task to DONE)
   and append to progress.txt. Start each entry with a line containing
   only: === ITERATION ===
   Then include:
   - Task completed and reference
   - Key decisions made
   - Files changed
   - Any blockers or notes for next iteration
   Keep entries concise. Sacrifice grammar for brevity.

7. If ALL tasks in the plan are DONE, output exactly: ${COMPLETE_SIGNAL}

ONLY WORK ON A SINGLE TASK.
Subagents are for I/O-heavy recon and parallel writes.
The main loop is for strategy and implementation.
PROMPT
}

# --- Run one iteration ---
run_iteration() {
  local cli="$1"
  local docker_available="$2"
  local prompt
  prompt="$(build_prompt "$cli")"

  case "$cli" in
    claude)
      if [ "$docker_available" = "true" ] && [ "$MAX_ITERATIONS" -gt 1 ]; then
        docker sandbox run claude -p "$prompt" \
          --dangerously-skip-permissions \
          --output-format=stream-json \
          --verbose
      else
        echo "$prompt" | claude -p \
          --dangerously-skip-permissions \
          --verbose
      fi
      ;;
    amp)
      echo "$prompt" | amp
      ;;
    ollama)
      # For ollama, pipe through a basic agent harness
      # Adjust model name as needed
      echo "$prompt" | ollama run "${OLLAMA_MODEL:-llama3.3}" --nowordwrap
      ;;
    *)
      echo "ERROR: Unsupported CLI: $cli" >&2
      exit 1
      ;;
  esac
}

# --- Main loop ---
main() {
  local cli
  cli="$(detect_cli)"
  local docker_available
  docker_available="$(detect_docker)"

  # Preflight checks
  [ ! -f "$PLAN_FILE" ] && echo "ERROR: $PLAN_FILE not found. Run /review-to-plan first." >&2 && exit 1
  [ ! -f "AGENTS.md" ] && [ ! -f "CLAUDE.md" ] && echo "WARNING: No AGENTS.md or CLAUDE.md found." >&2

  # Create progress file if missing
  [ ! -f "$PROGRESS_FILE" ] && touch "$PROGRESS_FILE"

  # Create failures log
  touch ralph-failures.log

  local branch
  branch="$(git branch --show-current)"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Ralph Wiggum Loop"
  echo " CLI:        $cli"
  echo " Docker:     $docker_available"
  echo " Branch:     $branch"
  echo " Max tasks:  $MAX_ITERATIONS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  for ((i = 1; i <= MAX_ITERATIONS; i++)); do
    echo ""
    echo "======================== ITERATION $i / $MAX_ITERATIONS ========================"
    echo ""

    # Record HEAD before iteration for failure detection
    local head_before
    head_before="$(git rev-parse HEAD)"

    local result
    result="$(run_iteration "$cli" "$docker_available")"
    echo "$result"

    # Detect failed iterations (no commit produced)
    local head_after
    head_after="$(git rev-parse HEAD)"
    if [ "$head_before" = "$head_after" ]; then
      local dirty
      dirty="$(git status --porcelain 2>/dev/null)"
      if [ -n "$dirty" ]; then
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) iteration=$i uncommitted-changes" >> ralph-failures.log
      else
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) iteration=$i no-change" >> ralph-failures.log
      fi
    fi

    # Sliding window: keep only the last 3 progress blocks
    # Each block starts with "=== ITERATION ==="
    local block_count
    block_count="$(grep -c '^=== ITERATION ===$' "$PROGRESS_FILE" 2>/dev/null || echo 0)"
    if [ "$block_count" -gt 3 ]; then
      local skip=$((block_count - 3))
      awk -v skip="$skip" '
        /^=== ITERATION ===$/ { count++ }
        count > skip { print }
      ' "$PROGRESS_FILE" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE"
    fi

    # Push after each iteration
    git push origin "$branch" 2>/dev/null || true

    # Check for completion signal
    if [[ "$result" == *"$COMPLETE_SIGNAL"* ]]; then
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo " All tasks complete. Ralph is done."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      exit 0
    fi
  done

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Reached max iterations ($MAX_ITERATIONS)."
  echo " Check IMPLEMENTATION_PLAN.md for remaining tasks."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main "$@"

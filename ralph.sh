#!/usr/bin/env bash
# ralph.sh — HITL coding loop for ralph-skills repo
# Based on Geoffrey Huntley's methodology
#
# Usage:
#   ./ralph.sh [iterations]     # Default: 1 (HITL mode)
#   ./ralph.sh 1                # Single iteration (watch mode)
#
# Prerequisites:
#   - IMPLEMENTATION_PLAN.md in project root
#   - AGENTS.md
#   - Git repo with clean working tree
#
# HITL mode only — no automated feedback loops for this skill repo.
# User is the backpressure.

set -euo pipefail

MAX_ITERATIONS="${1:-1}"
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
  else
    # Claude Code desktop app path
    local claude_path
    claude_path=$(find "$HOME/Library/Application Support/Claude/claude-code" -name "claude" -type f 2>/dev/null | sort -V | tail -1)
    if [ -n "$claude_path" ]; then
      echo "$claude_path"
    else
      echo "ERROR: Claude CLI not found. Set CLI= env var." >&2
      exit 1
    fi
  fi
}

# --- Build the prompt ---
build_prompt() {
  cat <<PROMPT
@${PLAN_FILE} @${PROGRESS_FILE}

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

4. This is a skill markdown repo — there are no automated feedback loops.
   Review your changes carefully before committing. Check:
   - SKILL.md frontmatter is valid YAML
   - Markdown formatting is correct
   - Shell scripts have valid syntax (bash -n file.sh)
   Do NOT commit if anything looks wrong.

5. When checks pass, make a git commit with a descriptive message
   referencing the task title.

6. Use a subagent to update IMPLEMENTATION_PLAN.md (set task to DONE)
   and append to progress.txt:
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
  local prompt
  prompt="$(build_prompt)"

  echo "$prompt" | "$cli" -p \
    --dangerously-skip-permissions \
    --verbose
}

# --- Main loop ---
main() {
  local cli
  cli="$(detect_cli)"

  # Preflight checks
  [ ! -f "$PLAN_FILE" ] && echo "ERROR: $PLAN_FILE not found. Run /plan-to-ralph first." >&2 && exit 1
  [ ! -f "AGENTS.md" ] && [ ! -f "CLAUDE.md" ] && echo "WARNING: No AGENTS.md or CLAUDE.md found." >&2

  # Create progress file if missing
  [ ! -f "$PROGRESS_FILE" ] && touch "$PROGRESS_FILE"

  local branch
  branch="$(git branch --show-current)"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Ralph Wiggum Loop (HITL)"
  echo " CLI:        $cli"
  echo " Branch:     $branch"
  echo " Max tasks:  $MAX_ITERATIONS"
  echo " Mode:       HITL — user is backpressure"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  for ((i = 1; i <= MAX_ITERATIONS; i++)); do
    echo ""
    echo "======================== ITERATION $i / $MAX_ITERATIONS ========================"
    echo ""

    local result
    result="$(run_iteration "$cli")"
    echo "$result"

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

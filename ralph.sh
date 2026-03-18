#!/usr/bin/env bash
# ralph.sh — HITL coding loop
# Based on Geoffrey Huntley's methodology
#
# Usage:
#   ./ralph.sh [iterations]     # Default: 1 (HITL mode)
#   ./ralph.sh 1                # Single iteration (watch mode)
#
# Environment variables (set by ralph-prep or manually):
#   CLI_TOOL   — "claude" or "ollama" (default: claude)
#   MODEL      — model name, e.g. "opus-4-6", "llama3:latest"
#   COST_CAP_ITERATIONS — max iterations based on $50 budget (default: 25)
#
# Prerequisites:
#   - IMPLEMENTATION_PLAN.md in project root
#   - AGENTS.md
#   - Git repo with clean working tree

set -euo pipefail

# --- Configuration ---
CLI_TOOL="${CLI_TOOL:-claude}"
MODEL="${MODEL:-}"
COST_CAP_ITERATIONS="${COST_CAP_ITERATIONS:-25}"
PLAN_FILE="IMPLEMENTATION_PLAN.md"
PROGRESS_FILE="progress.txt"
COMPLETE_SIGNAL="<promise>COMPLETE</promise>"
LAST_OUTPUT="/tmp/ralph-last-output-$$.txt"

# --- Apply cost cap ---
REQUESTED="${1:-1}"
if (( REQUESTED > COST_CAP_ITERATIONS )); then
  echo "WARNING: Requested $REQUESTED iterations exceeds cost cap ($COST_CAP_ITERATIONS at \$50 budget). Capping." >&2
  MAX_ITERATIONS="$COST_CAP_ITERATIONS"
else
  MAX_ITERATIONS="$REQUESTED"
fi

# --- Detect CLI tool ---
detect_cli() {
  if [ "$CLI_TOOL" = "ollama" ]; then
    if command -v ollama &>/dev/null; then
      echo "ollama"
    else
      echo "ERROR: CLI_TOOL=ollama but ollama not found on PATH." >&2
      exit 1
    fi
    return
  fi

  # Default: Claude
  if command -v claude &>/dev/null; then
    echo "claude"
  else
    # Claude Code desktop app path
    local claude_path
    claude_path=$(find "$HOME/Library/Application Support/Claude/claude-code" -name "claude" -type f 2>/dev/null | sort -V | tail -1)
    if [ -n "$claude_path" ]; then
      echo "$claude_path"
    else
      echo "ERROR: Claude CLI not found. Set CLI_TOOL= and ensure it's on PATH." >&2
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
   If the task feels like it has multiple sub-parts, implement ONLY the first
   sub-part and mark the task as IN PROGRESS, not DONE.

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

# --- Run one iteration (streams output in real-time) ---
run_iteration() {
  local cli="$1"
  local prompt
  prompt="$(build_prompt)"

  # Clear previous output
  : > "$LAST_OUTPUT"

  if [ "$CLI_TOOL" = "ollama" ]; then
    ollama run "$MODEL" < <(echo "$prompt") 2>&1 | tee "$LAST_OUTPUT"
  else
    local -a model_flag=()
    if [ -n "$MODEL" ]; then
      model_flag=(--model "$MODEL")
    fi
    echo "$prompt" | "$cli" -p \
      --dangerously-skip-permissions \
      --verbose \
      "${model_flag[@]}" \
      2>&1 | tee "$LAST_OUTPUT"
  fi
}

# --- Cleanup temp files ---
cleanup() {
  rm -f "$LAST_OUTPUT"
}
trap cleanup EXIT

# --- Main loop ---
main() {
  local cli
  cli="$(detect_cli)"

  # Preflight checks
  [ ! -f "$PLAN_FILE" ] && echo "ERROR: $PLAN_FILE not found. Run /plan-to-ralph first." >&2 && exit 1
  [ ! -f "AGENTS.md" ] && [ ! -f "CLAUDE.md" ] && echo "WARNING: No AGENTS.md or CLAUDE.md found." >&2

  # Check for TODO tasks using the canonical grep pattern
  local todo_count
  todo_count=$(grep -c '\*\*Status:\*\* TODO' "$PLAN_FILE" 2>/dev/null || echo "0")
  if [ "$todo_count" -eq 0 ]; then
    echo "ERROR: No TODO tasks found in $PLAN_FILE — nothing to do." >&2
    echo "  (Searched for '**Status:** TODO' — see references/plan-schema.md for format)" >&2
    exit 1
  fi

  # Create progress file if missing
  [ ! -f "$PROGRESS_FILE" ] && touch "$PROGRESS_FILE"

  local branch
  branch="$(git branch --show-current)"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Ralph Wiggum Loop (HITL)"
  echo " CLI:        $CLI_TOOL ($cli)"
  echo " Model:      ${MODEL:-default}"
  echo " Branch:     $branch"
  echo " Max tasks:  $MAX_ITERATIONS (cost cap: $COST_CAP_ITERATIONS)"
  echo " TODO tasks: $todo_count"
  echo " Mode:       HITL — user is backpressure"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  for ((i = 1; i <= MAX_ITERATIONS; i++)); do
    echo ""
    echo "======================== ITERATION $i / $MAX_ITERATIONS ========================"
    echo ""

    # Stream output in real-time via tee
    run_iteration "$cli"

    # Check for completion signal in captured output
    if grep -q "$COMPLETE_SIGNAL" "$LAST_OUTPUT" 2>/dev/null; then
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo " All tasks complete. Ralph is done."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      # Push once at the end
      git push origin "$branch" 2>/dev/null || true
      exit 0
    fi
  done

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Reached max iterations ($MAX_ITERATIONS)."
  echo " Check IMPLEMENTATION_PLAN.md for remaining tasks."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  # Push once at the end
  git push origin "$branch" 2>/dev/null || true
}

main "$@"

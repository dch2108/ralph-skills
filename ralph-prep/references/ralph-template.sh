#!/usr/bin/env bash
# ralph.sh — Autonomous coding loop (Ralph Wiggum pattern)
# Based on Geoffrey Huntley's methodology: https://ghuntley.com/ralph/
#
# Usage:
#   ./ralph.sh           # Single HITL iteration (default — watch live)
#   ./ralph.sh 1         # Same as above
#   ./ralph.sh 30        # AFK batch run (30 iterations max)
#
# Prerequisites:
#   - Git repo with clean working tree
#   - PLAN.md with unchecked tasks (- [ ] format)
#   - AGENTS.md with feedback loop commands
#
# Environment:
#   CLI=claude|amp|ollama    Override CLI detection
#   OLLAMA_MODEL=llama3.3   Model for ollama (default: llama3.3)

set -euo pipefail

MAX_ITERATIONS="${1:-1}"
PLAN_FILE="PLAN.md"
PROGRESS_FILE="progress.txt"
COMPLETE_SIGNAL="<promise>COMPLETE</promise>"
ITERATION_LOG=".ralph-iteration.log"
PROMPT_FILE=".ralph-prompt.tmp"

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

# --- Plan parsing (source of truth for format) ---
#
# PLAN.md is a numbered checkbox list:
#   - [x] 1. Completed task description
#   - [ ] 2. Next task to do
#   - [ ] 3. Future task
#
# extract_next_task: returns the first unchecked line
# count_done: count checked items
# count_remaining: count unchecked items

extract_next_task() {
  grep -m1 '^\- \[ \]' "$PLAN_FILE" || return 1
}

count_done() {
  local n
  n=$(grep -c '^\- \[x\]' "$PLAN_FILE" 2>/dev/null) || true
  echo "${n:-0}"
}

count_remaining() {
  local n
  n=$(grep -c '^\- \[ \]' "$PLAN_FILE" 2>/dev/null) || true
  echo "${n:-0}"
}

# --- Build the prompt (scoped to a SINGLE task) ---
#
# Short prompt — AGENTS.md carries project-specific instructions
# (feedback loops, subagent rules, conventions). This prompt only
# adds the loop-specific context: which task, progress, and how
# to mark done.
build_prompt() {
  local task_line done_count remaining_count progress_content
  task_line="$(extract_next_task)" || return 1
  done_count="$(count_done)"
  remaining_count="$(count_remaining)"
  progress_content=""
  [ -f "$PROGRESS_FILE" ] && [ -s "$PROGRESS_FILE" ] && progress_content="$(cat "$PROGRESS_FILE")"

  cat <<PROMPT
You are Ralph. Complete this one task:

${task_line}

Progress: ${done_count} done, ${remaining_count} remaining.
${progress_content:+
Previous iterations:
${progress_content}
}
When done:
1. Change - [ ] to - [x] for your task line (match the number) in PLAN.md.
2. Commit your changes with a descriptive message.
3. Append a brief note to progress.txt (what you did, files changed, any blockers).
   Start each entry with: === ITERATION ===
4. If ALL tasks in the plan are now done, output exactly: ${COMPLETE_SIGNAL}
5. STOP. Do not continue to other tasks. The loop handles iteration.
PROMPT
}

# --- Run one iteration with live-streaming output ---
#
# Uses 'script' to allocate a pseudo-tty. Without a pty, CLI tools
# detect they're piped and buffer all output — the human sees nothing
# until the iteration finishes.
run_iteration() {
  local cli="$1"
  local prompt
  prompt="$(build_prompt "$cli")"

  : > "$ITERATION_LOG"

  # Write prompt to temp file (avoids argument length limits)
  printf '%s' "$prompt" > "$PROMPT_FILE"

  local cmd
  case "$cli" in
    claude)
      cmd="claude -p ${CLAUDE_FLAGS:---verbose} < '$PROMPT_FILE'"
      ;;
    amp)
      cmd="amp < '$PROMPT_FILE'"
      ;;
    ollama)
      cmd="ollama run '${OLLAMA_MODEL:-llama3.3}' --nowordwrap < '$PROMPT_FILE'"
      ;;
    *)
      echo "ERROR: Unsupported CLI: $cli" >&2
      exit 1
      ;;
  esac

  # 'script' wraps the CLI in a pty for live streaming + log capture
  script -q "$ITERATION_LOG" bash -c "$cmd"

  rm -f "$PROMPT_FILE"
}

# --- Main loop ---
main() {
  local cli
  cli="$(detect_cli)"

  # Preflight: git repo
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "ERROR: Not a git repository. Ralph requires git for commit tracking." >&2
    echo "  Run: git init && git add -A && git commit -m 'initial commit'" >&2
    exit 1
  fi

  # Preflight: clean working tree (warn only)
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "WARNING: Working tree has uncommitted changes. Consider committing first." >&2
  fi

  # Preflight: plan file
  if [ ! -f "$PLAN_FILE" ]; then
    echo "ERROR: $PLAN_FILE not found. Run /plan-to-ralph first." >&2
    exit 1
  fi

  [ ! -f "AGENTS.md" ] && [ ! -f "CLAUDE.md" ] && echo "WARNING: No AGENTS.md or CLAUDE.md found." >&2

  # Preflight: remaining tasks
  local remaining
  remaining="$(count_remaining)"
  if [ "$remaining" -eq 0 ]; then
    echo "All tasks are done. Nothing for Ralph to do." >&2
    exit 0
  fi

  # Create progress file if missing
  [ ! -f "$PROGRESS_FILE" ] && touch "$PROGRESS_FILE"

  # Create failures log
  touch ralph-failures.log

  local branch
  branch="$(git branch --show-current)"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Ralph Wiggum Loop"
  echo " CLI:        $cli"
  echo " Branch:     $branch"
  echo " Tasks:      $remaining remaining"
  echo " Iterations: $MAX_ITERATIONS max"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  for ((i = 1; i <= MAX_ITERATIONS; i++)); do
    echo ""
    echo "======================== ITERATION $i / $MAX_ITERATIONS ========================"

    # Show which task is about to run
    local next_task
    next_task="$(extract_next_task)"
    echo "  → $next_task"
    echo ""

    # Snapshot state before iteration
    local done_before head_before
    done_before="$(count_done)"
    head_before="$(git rev-parse HEAD)"

    # Run iteration — output streams live via pseudo-tty
    run_iteration "$cli"

    echo ""
    echo "--- Post-iteration checks ---"

    # One-task enforcement: check DONE delta
    local done_after done_delta
    done_after="$(count_done)"
    done_delta=$((done_after - done_before))

    if [ "$done_delta" -eq 0 ]; then
      echo "⚠  No task was completed this iteration."
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) iteration=$i no-task-completed" >> ralph-failures.log
    elif [ "$done_delta" -gt 1 ]; then
      echo "✗  $done_delta tasks marked done (expected 1). Review carefully."
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) iteration=$i multi-task-violation done_delta=$done_delta" >> ralph-failures.log
    else
      echo "✓  Task completed. ($done_after / $((done_after + $(count_remaining))) done)"
    fi

    # Detect no-commit iterations
    local head_after
    head_after="$(git rev-parse HEAD)"
    if [ "$head_before" = "$head_after" ]; then
      if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        echo "⚠  Changes exist but no commit was made."
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) iteration=$i uncommitted-changes" >> ralph-failures.log
      fi
    fi

    # Sliding window: keep only the last 3 progress blocks
    local block_count
    block_count="$(grep -c '^=== ITERATION ===$' "$PROGRESS_FILE" 2>/dev/null)" || true
    block_count="${block_count:-0}"
    if [ "$block_count" -gt 3 ]; then
      local skip=$((block_count - 3))
      awk -v skip="$skip" '
        /^=== ITERATION ===$/ { count++ }
        count > skip { print }
      ' "$PROGRESS_FILE" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE"
    fi

    # Check for completion signal
    if grep -q "$COMPLETE_SIGNAL" "$ITERATION_LOG" 2>/dev/null; then
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo " All tasks complete. Ralph is done."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      git push origin "$branch" 2>/dev/null || true
      exit 0
    fi

    # Check remaining
    remaining="$(count_remaining)"
    if [ "$remaining" -eq 0 ]; then
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo " All tasks marked done. Loop complete."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      git push origin "$branch" 2>/dev/null || true
      exit 0
    fi

    echo "$remaining tasks remaining."
    echo ""
  done

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Reached max iterations ($MAX_ITERATIONS)."
  echo " Check $PLAN_FILE for remaining tasks."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  git push origin "$branch" 2>/dev/null || true
}

main "$@"

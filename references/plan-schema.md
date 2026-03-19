# Plan Format

`PLAN.md` is a numbered checkbox list. Each line is one task.

## Example

```markdown
# Plan

- [x] 1. Completed task description (1-2 sentences)
- [x] 2. Another completed task
- [ ] 3. Next task to do — ralph.sh picks this one
- [ ] 4. Future task with enough context for a fresh agent
- [ ] 5. Another future task
```

## Rules

- One task per line, numbered sequentially
- Task description: 1-2 sentences max
- `- [ ]` = not started, `- [x]` = done
- ralph.sh extracts the first `- [ ]` line
- Order matters: dependencies first, then importance

## Parsing

ralph.sh is the **source of truth** for format parsing. See `extract_next_task()`,
`count_done()`, and `count_remaining()` in `ralph-prep/references/ralph-template.sh`.

```bash
# These grep patterns are canonical:
extract_next_task:  grep -m1 '^\- \[ \]' PLAN.md
count_done:         grep -c '^\- \[x\]' PLAN.md
count_remaining:    grep -c '^\- \[ \]' PLAN.md
```

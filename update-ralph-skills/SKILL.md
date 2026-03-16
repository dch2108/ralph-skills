---
name: update-ralph-skills
metadata:
  version: '1.1'
  author: dch2108
description: >
  Update ralph-skills to the latest version from GitHub. Pulls the latest
  changes, re-runs setup to fix symlinks, and reports the new version numbers.
  Use when the user says "update ralph skills", "update ralph", "pull latest
  ralph", or "check for ralph updates".
---

# Update Ralph Skills

Pull the latest ralph-skills from GitHub and verify the update.

## Instructions

### Step 1: Find the install

Check for the ralph-skills repo in these locations (in order):

1. `~/.claude/skills/ralph-skills/` (global install)
2. `.claude/skills/ralph-skills/` (project install)

If neither exists, tell the user: "ralph-skills is not installed. Install with: `git clone https://github.com/dch2108/ralph-skills.git ~/.claude/skills/ralph-skills && cd ~/.claude/skills/ralph-skills && ./setup`"

### Step 2: Check if it's a git repo

If the directory has no `.git/` folder, it's a project-level copy (not cloneable). Tell the user:
"This is a project-level copy without git history. Update the global install first, then re-copy:
```
cd ~/.claude/skills/ralph-skills && git pull && ./setup
cp -Rf ~/.claude/skills/ralph-skills .claude/skills/ralph-skills
rm -rf .claude/skills/ralph-skills/.git
cd .claude/skills/ralph-skills && ./setup
```"

### Step 3: Read current versions

Before pulling, read the `metadata.version` from each skill's `SKILL.md` frontmatter:
- `review-to-plan/SKILL.md`
- `ralph-prep/SKILL.md`
- `setup-feedback/SKILL.md`
- `update-ralph-skills/SKILL.md`

Record these as "before" versions.

### Step 4: Pull latest

```bash
cd ~/.claude/skills/ralph-skills && git pull origin main
```

If this fails due to local changes, stash them first:
```bash
git stash && git pull origin main
```

### Step 5: Re-run setup

```bash
cd ~/.claude/skills/ralph-skills && ./setup
```

This ensures any new skills get symlinked and any removed skills get cleaned up.

### Step 6: Read new versions

Read the `metadata.version` from each skill's `SKILL.md` again. Compare with "before" versions.

### Step 7: Report

```
## ralph-skills updated

| Skill | Before | After |
|-------|--------|-------|
| review-to-plan | 1.0 | 1.1 |
| ralph-prep | 1.0 | 1.1 |
| setup-feedback | 1.0 | 1.1 |
| update-ralph-skills | 1.0 | 1.1 |

Changes pulled. Symlinks refreshed. Run /context to verify.
```

If all versions are the same, report: "Already up to date (all skills at version X.Y)."

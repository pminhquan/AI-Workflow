# Git Policy and Version Control Governance

This document establishes the boundaries, permissions, and responsibilities governing version control within the AI-assisted development workflow.

## 1. Division of Responsibilities

### Human Engineer (Exclusive Authority)
The human engineer holds sole authority and ownership over repository state and history:
- Staging changes (`git add`)
- Creating commits (`git commit`)
- Pushing to remotes (`git push`)
- Creating or moving tags (`git tag`)
- Branch lifecycle (creation, checkout, merge, rebase, deletion)
- Destructive operations (reset, restore, clean, stash drop)
- Code review approval and deployment triggers

### AI Assistant (Read-Only Observer)
The AI assistant operates strictly with read-only inspection capabilities:
- Inspect current working tree status (`git status`)
- Inspect pending diffs (`git diff`, `git diff --stat`)
- Check base commit or revision (`git rev-parse`)
- View commit history for context (`git log -n <limit>`)

## 2. Forbidden Git Operations for AI Agents

Under no circumstances may an AI agent run or trigger any of the following Git commands:
- `git add`
- `git commit`
- `git push`
- `git tag`
- `git reset` (soft, mixed, or hard)
- `git restore`
- `git clean`
- `git checkout -f`
- `git rebase`
- `git merge`
- `git branch` (creation, deletion, rename)
- `git stash` (pop, drop, clear)
- `git cherry-pick`

Any automated script or prompt executed by an AI agent must adhere to this prohibition.

## 3. Permitted Read-Only Git Operations

AI agents may execute read-only queries when necessary to verify working tree status or diff boundaries:
- `git status --porcelain` or `git status --short`
- `git diff --stat` or `git diff <path>`
- `git rev-parse --short HEAD`
- `git log -n 5 --oneline`

All read-only operations must be conservative, avoiding paging, interactive prompts, or massive output dumps.

## 4. Working Tree Hygiene

1. **Allowlist Compliance**: Agents must modify only files specified in the active task `ALLOWLIST`.
2. **No Extraneous Files**: Do not generate scratch files, temporary logs, or backup copies inside source directories.
3. **Diff Verification**: Before declaring a task finished, verify that the active diff contains only intentional, minimal modifications directly answering the task goal.
4. **Human Handover**: Upon task completion, report the exact list of changed files under `CHANGED:` so the human engineer can inspect and commit them safely.

# Quick Task Template (Compatibility Alias)

Compact task handoff format conforming to the canonical routing contract defined in [`core/TASK_TEMPLATE.md`](TASK_TEMPLATE.md).

---

## 1. Minimal Quick Input Format

Every task uses the six required fields of the canonical routing contract; state each field explicitly:

```text
INTENT: <goal, action, defect, or objective to solve>
RISK: <Low | Medium | High | Critical>
TARGET: <project path, repository, or component>
ALLOWLIST: <mandatory explicit list of file paths/patterns for writes; NONE for read-only>
REVIEW: <conditional review rule: SELF | PEER | HUMAN>
TEST: <focused verification command, tier (Tier 0-4), or evidence>
```

Behavior-changing repository work, including test or source changes, is delegated to Antigravity. Native Codex is limited to read-only analysis, verification, and documentation/non-executable artifact writes. `/fix` diagnoses before delegation, `/test` creates a test request, and `/debug` is diagnosis only.

### Shortcuts Compatibility

Workflow shortcuts documented in [`prompts/shortcuts.md`](../prompts/shortcuts.md) (`/fix`, `/feature`, `/debug`, `/audit`, `/review`, `/test`, `/release`, `/ui`, `/db`, `/security`) serve as thin compatibility aliases that map directly into this 6-field canonical contract and provider routing.

---

## 2. Core Governance Invariants

- **Mandatory Allowlist**: Write tasks require explicit non-empty `ALLOWLIST`; write operations without an allowlist are blocked.
- **Human Authority**: Exclusive human approval for `git add`, `git commit`, `git push`, `git tag`, deployments, and releases.
- **Output Contract**: Normalized completion block with mandatory repository-state checks (`git status --short`, `git diff --name-only`, `git diff --check`):
  ```text
  STATUS: <PASS | FAIL | BLOCKED | UNVERIFIED>
  CHANGED: <List of modified file paths relative to project root verified via git status/diff, or NONE>
  TEST: <Executed test/verification command(s) and results summary>
  RISK: <Identified risks, caveats, or residual uncertainties>
  NEXT: <Recommended next action for human engineer or subsequent phase>
  ```

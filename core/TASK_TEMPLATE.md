# Standard Task Template

This template defines the contract between the human engineer and the AI assistant for any work item.

---

## Task Definition Contract

```markdown
### MODE
<!-- Required: One of AUDIT, IMPLEMENT, REVIEW, DEBUG, RELEASE_CHECK -->
[AUDIT | IMPLEMENT | REVIEW | DEBUG | RELEASE_CHECK]

### PROJECT
<!-- Required: Project identifier or repository name -->
[Project Name]

### RISK
<!-- Required: Risk level (Low | Medium | High | Critical) and brief risk rationale -->
[Low | Medium | High | Critical] - [Risk explanation]

### BASE_SHA
<!-- Required: Target commit SHA, tag, or base revision -->
[Git commit SHA or revision]

### GOAL
<!-- Required: Objective and concise definition of what needs to be done -->
[Clear statement of the objective and problem to be solved]

### ALLOWLIST
<!-- Required: Explicit list of file paths or glob patterns permitted to be created or modified. Use NONE for read-only modes. -->
- [path/to/file1]
- [path/to/file2]

### FORBIDDEN_ACTIONS
<!-- Required: Explicit list of restricted actions, forbidden files, or operations -->
- No automatic git add, commit, push, tag, reset, restore, or clean.
- No modifications outside ALLOWLIST.
- No new external dependencies without prior human approval.
- No secrets or environment credentials committed.

### ACCEPTANCE_CRITERIA
<!-- Required: Testable, verifiable conditions that must be satisfied -->
1. [Criterion 1]
2. [Criterion 2]
3. [Criterion 3]

### GATES
<!-- Required: Verification gates to be passed (e.g., Test Tier 0-4, syntax check, diff verification) -->
- [ ] Tier Gate: [Tier 0 / Tier 1 / Tier 2 / Tier 3 / Tier 4]
- [ ] Read-only diff check verifies changes are within ALLOWLIST
- [ ] Acceptance criteria verified with runnable tests or concrete evidence

### REQUIRED_OUTPUT
<!-- Required: Agent must conclude with the standard output block below -->
STATUS: [COMPLETED | IN_PROGRESS | BLOCKED | FAILED]
CHANGED: [List of changed files or NONE]
TEST: [Test command(s) executed and result summary]
RISK: [Identified risks, caveats, or residual uncertainties]
NEXT: [Recommended next action for human or next task phase]
```

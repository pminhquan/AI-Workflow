# Quick Task Template

Compact daily-use task input format for fast, low-friction task handoff.

---

## 1. Quick Task Input Format

### Required Fields
```text
MODE: [AUDIT | IMPLEMENT | REVIEW | DEBUG | RELEASE_CHECK]
PROJECT: [Project Name or Path]
GOAL: [Clear statement of what needs to be done]
RISK: [Low | Medium | High | Critical] - [Brief risk explanation]
```

### Optional Fields
```text
ALLOWLIST: [Optional: comma-separated file paths or glob patterns permitted to be modified]
CONSTRAINTS: [Optional: specific restrictions, non-goals, or boundaries]
```

### Example
```text
MODE: IMPLEMENT
PROJECT: auth-service
GOAL: Add email format validation before account registration
RISK: Low - local input validation change
ALLOWLIST: src/validators/email.ts, tests/validators/email.test.ts
CONSTRAINTS: No external validator dependencies; use stdlib regex
```

---

## 2. Automated Workflow Derivations

When receiving this compact input, the workflow automatically resolves parameters that previously required manual template configuration:

| Component | Derivation Logic |
|---|---|
| **Agents** | Selected automatically based on `MODE` (e.g., `developer.md` for IMPLEMENT, `reviewer.md` for REVIEW, `architect.md` for AUDIT, `tester.md` for test coverage, `security.md` for sensitive paths). |
| **Skills** | Inferred automatically from `PROJECT` context, repository stack, and file extensions using `.ai/CONTEXT.md` and `skills/`. |
| **Test Tier** | Determined automatically from `MODE`, `RISK`, and touched files per `core/TEST_POLICY.md` (Tier 0 for documentation/static, Tier 1 for UI, Tier 2 for logic, Tier 3 for security/DB, Tier 4 for release). |
| **Verification Rules** | Derived automatically from the assigned test tier, including syntax parsing, targeted test runs, and boundary verification. |
| **Git Policy** | Derived and enforced automatically from `core/GIT_POLICY.md`: AI is strictly a read-only observer. |

---

## 3. Preserved Safety Invariants

Even with minimal input, all core workflow protections remain non-negotiable:

- **No Auto Commit & No Auto Push**: Automatic Git mutations (`git add`, `git commit`, `git push`, `git tag`, `git reset`, `git restore`, `git clean`) are strictly forbidden.
- **Human Git Boundary**: All staging, commits, branch operations, and deployments remain exclusive human actions.
- **Mandatory Repository Verification Gate**: Before completing any task, the agent must run `git status --short`, `git diff --name-only`, and `git diff --check`. Authoritative priority: `actual workspace > git diff > worker artifacts`.
- **Standard Output Contract**: Every completion response must conclude with:
  ```text
  STATUS: <COMPLETED | IN_PROGRESS | WARNING | BLOCKED | FAILED>
  CHANGED: <List of modified files, or NONE>
  TEST: <Summary of test commands and results>
  RISK: <Identified risks or assumptions>
  NEXT: <Recommended next action for human>
  ```

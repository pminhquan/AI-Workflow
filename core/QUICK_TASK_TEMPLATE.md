# Quick Task Template

Compact daily-use task input format for fast, low-friction task handoff.

---

## 1. Minimal Quick Input Format

### Required Inputs
```text
PROJECT: <path>
TASK: <goal>
```

### Optional Overrides
```text
RISK: [Optional: Low | Medium | High | Critical - overrides inferred risk]
ALLOWLIST: [Optional: comma-separated file paths or glob patterns permitted to be modified]
CONSTRAINTS: [Optional: specific restrictions, non-goals, or boundaries]
```

### Example
```text
PROJECT: auth-service
TASK: Add email format validation before account registration
RISK: Low
ALLOWLIST: src/validators/email.ts, tests/validators/email.test.ts
CONSTRAINTS: No external validator dependencies; use stdlib regex
```

---

## 2. Automated Parameter Inference

When receiving minimal input, the workflow deterministically infers provisional execution parameters using `core/TASK_CLASSIFICATION.md`:

| Inferred Parameter | Deterministic Inference Logic |
|---|---|
| **Category** | Deterministically classified into one of 10 categories (`UI`, `BACKEND_LOGIC`, `DATABASE`, `AUTH_SECURITY`, `UPLOAD_FILE`, `TESTING`, `DEBUG`, `DOCUMENTATION`, `RELEASE`, `MIXED`) based on normalized path and keyword signatures. |
| **MODE** | Inferred from category default `MODE` (`IMPLEMENT`, `DEBUG`, `RELEASE_CHECK`). Category mappings are provisional context only and do not authorize execution on `ESCALATE`. |
| **RISK** | Inferred from category default `RISK` (e.g., `Low` for UI/docs/testing, `Medium` for backend logic/debug, `High` for DB/auth/upload/release/mixed). Any High or Critical risk mandates `ESCALATE`. |
| **Agents** | Selected from repository-observed agent roles (`architect.md`, `developer.md`, `reviewer.md`, `tester.md`, `security.md`) matched to the category. |
| **Skills** | Derived from category recommended skills (`java-web`, `python`, `database`, `frontend`, `release`) and optional repository inspection (e.g., source file layout or optional `.ai/CONTEXT.md` if present, without AI-specific project assumptions). For `MIXED`, resolves to the union of participating category skills. |
| **Test Tier** | Inferred from category default test tier (`Tier 0` to `Tier 4`) per `core/TEST_POLICY.md`. |
| **Allowlist** | If omitted, bounded to referenced paths or project workspace. |
| **Constraints** | Core safety invariants apply unconditionally. |

### Precedence and Escalation Rules
1. **Explicit Field Precedence**: Explicit user values (`RISK:`, `ALLOWLIST:`, `CONSTRAINTS:`) unconditionally override inferred values. Explicit `RISK: High` or `RISK: Critical` mandates an immediate `ESCALATE` outcome and halts execution.
2. **Path Precedence**: Concrete file paths take precedence over general task keywords.
3. **Tie / Overlap**: Multi-domain tasks resolve to `MIXED` with skills as the union of participating category skills, resolving to `High` risk and triggering `ESCALATE`.
4. **Mandatory Escalation (No Guessing)**: Ambiguous, contradictory, unknown-scope, or High/Critical-risk tasks MUST produce an explicit `ESCALATE` outcome and halt immediately for human clarification/confirmation. Never guess, assume missing intent, or default to `MODE: AUDIT`. Category/default mappings provide provisional context only, never authorization to execute. When classification returns `ESCALATE`, the standard response uses `STATUS: BLOCKED` and `NEXT` requests human clarification or confirmation.

---

## 3. Preserved Safety Invariants

Task classification and automatic inference never relax security or version control boundaries:

- **No Mutating Git Permissions**: Classification NEVER grants permission for `git add`, `git commit`, `git push`, `git tag`, `git reset`, `git restore`, or `git clean`.
- **No Deployment**: Automated continuous deployment and remote releases are strictly forbidden.
- **No Destructive Database Operations**: Automated `DROP TABLE`, `TRUNCATE`, destructive migrations, or production data wiping are strictly prohibited.
- **Human Git Boundary**: All staging, committing, branch management, and releases remain exclusive human responsibilities.
- **Mandatory Repository Verification Gate**: Before completing any task, the agent must execute:
  1. `git status --short`
  2. `git diff --name-only`
  3. `git diff --check`
  Authoritative priority order: `actual workspace > git diff > worker artifacts`.
- **Standard Output Contract**: Every completion response must conclude with:
  ```text
  STATUS: <COMPLETED | IN_PROGRESS | WARNING | BLOCKED | FAILED>
  CHANGED: <List of modified files, or NONE>
  TEST: <Summary of test commands and results>
  RISK: <Identified risks or assumptions>
  NEXT: <Recommended next action for human>
  ```

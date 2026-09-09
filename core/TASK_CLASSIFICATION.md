# Task Classification and Inference Policy

This document establishes deterministic rules for classifying tasks and inferring workflow execution parameters (agent roles, skills, test tiers, and execution modes) from minimal input without guesswork.

---

## 1. Deterministic Task Categories

Every task is deterministically classified into one of the following ten categories based on normalized keyword, path, and file matching. Only repository-observed agents (`architect.md`, `developer.md`, `reviewer.md`, `tester.md`, `security.md`) and skills (`java-web`, `python`, `database`, `frontend`, `release`) are assigned.

> [!IMPORTANT]
> **Provisional Context Only**: Category and default parameter mappings provide provisional context only; they NEVER constitute authorization to execute. Any task in a high-risk category or marked with explicit `RISK: High` or `RISK: Critical` mandates an explicit `ESCALATE` outcome and halts for human clarification/confirmation.

| Category | Default MODE | Default RISK | Recommended Agents | Recommended Skills | Default Test Tier | Path & Normalized Keyword Signatures | High-Risk Escalation Rule |
|---|---|---|---|---|---|---|---|
| `UI` | `IMPLEMENT` | `Low` | `developer.md`, `reviewer.md` | `frontend` | `Tier 1` | `ui`, `component`, `css`, `html`, `frontend`, `style`, `button`, `form`, `view`, `layout`, `page`; paths: `components/`, `styles/`, `*.css`, `*.html`, `*.tsx`, `*.vue` | Standard verification gate applies. Escalates to `ESCALATE` only if explicit `RISK: High/Critical`. |
| `BACKEND_LOGIC` | `IMPLEMENT` | `Medium` | `developer.md`, `tester.md`, `reviewer.md` | `java-web`, `python` | `Tier 2` | `api`, `service`, `endpoint`, `controller`, `handler`, `business logic`, `util`, `algorithm`, `parse`; paths: `controller/`, `service/`, `api/`, `*.java`, `*.py` | Standard verification gate applies. Escalates to `ESCALATE` only if explicit `RISK: High/Critical`. |
| `DATABASE` | `IMPLEMENT` | `High` | `developer.md`, `architect.md`, `reviewer.md` | `database` | `Tier 3` | `db`, `database`, `schema`, `migration`, `sql`, `query`, `table`, `entity`, `repository`; paths: `migrations/`, `db/`, `*.sql` | **MANDATORY ESCALATE**: High-risk default; halts for human confirmation before any database or schema action. |
| `AUTH_SECURITY` | `IMPLEMENT` | `High` | `security.md`, `developer.md`, `reviewer.md` | `java-web`, `python`, `database` | `Tier 3` | `auth`, `login`, `token`, `jwt`, `permission`, `credential`, `crypto`, `security`, `rbac`, `session`; paths: `auth/`, `security/` | **MANDATORY ESCALATE**: High-risk default; halts for human confirmation before any auth or security modification. |
| `UPLOAD_FILE` | `IMPLEMENT` | `High` | `developer.md`, `security.md`, `tester.md` | `java-web`, `python` | `Tier 3` | `upload`, `multipart`, `file upload`, `attachment`, `storage`, `s3`, `payload`, `io`; paths: `upload/`, `storage/` | **MANDATORY ESCALATE**: High-risk default; halts for human confirmation before any file storage or parsing execution. |
| `TESTING` | `IMPLEMENT` | `Low` | `tester.md`, `developer.md` | `java-web`, `python`, `frontend` | `Tier 2` | `test`, `tests`, `unit test`, `integration test`, `spec`, `coverage`, `mock`; paths: `test/`, `tests/`, `*_test.*`, `*.spec.*` | Standard verification gate applies. Escalates to `ESCALATE` only if explicit `RISK: High/Critical`. |
| `DEBUG` | `DEBUG` | `Medium` | `developer.md`, `tester.md`, `reviewer.md` | `java-web`, `python`, `frontend`, `database` | `Tier 2` | `fix`, `bug`, `defect`, `error`, `crash`, `issue`, `root cause`, `regression`, `stacktrace`, `exception` | Standard verification gate applies. Escalates to `ESCALATE` only if explicit `RISK: High/Critical`. |
| `DOCUMENTATION` | `IMPLEMENT` | `Low` | `architect.md`, `reviewer.md` | `release` | `Tier 0` | `doc`, `docs`, `readme`, `guide`, `comment`, `specification`, `markdown`; paths: `docs/`, `*.md` | Standard verification gate applies. Escalates to `ESCALATE` only if explicit `RISK: High/Critical`. |
| `RELEASE` | `RELEASE_CHECK` | `High` | `architect.md`, `tester.md`, `reviewer.md` | `release` | `Tier 4` | `release`, `publish`, `version`, `tag`, `changelog`, `pre-release`, `milestone`, `build candidate` | **MANDATORY ESCALATE**: High-risk default; halts for human confirmation before release checks or staging actions. |
| `MIXED` | `IMPLEMENT` | `High` | `architect.md`, `developer.md`, `reviewer.md`, `tester.md` | Union of matched category skills (from `frontend`, `java-web`, `python`, `database`, `release`) | `Tier 3` | Cross-domain tasks matching multiple distinct categories (e.g., UI + BACKEND_LOGIC, DATABASE + UI) | **MANDATORY ESCALATE**: High-risk default; halts for human confirmation due to cross-domain risk. |

---

## 2. Deterministic Inference and Precedence Rules

Classification and parameter derivation follow strict deterministic precedence:

1. **Explicit Field Precedence (Highest)**:
   - If the task input explicitly specifies `RISK:`, `ALLOWLIST:`, or `CONSTRAINTS:`, the explicit user input unconditionally overrides any inferred value.
   - If explicit `RISK: High` or `RISK: Critical` is supplied, it immediately triggers the mandatory `ESCALATE` outcome and halts execution for human confirmation.
2. **Path & Extension Precedence**:
   - File paths in `ALLOWLIST:` or paths explicitly referenced in `TASK:` take priority over generic keyword matching (e.g., modifying `src/db/schema.sql` resolves to `DATABASE` even if the task description mentions UI).
3. **Normalized Keyword Precedence**:
   - The task description is normalized (lowercased, trimmed) and evaluated against the signature keywords of the categories.
4. **Tie & Overlap Resolution**:
   - When a task touches multiple categories across domains (e.g., UI frontend combined with database schema changes):
     - The category resolves to `MIXED`.
     - Recommended skills resolve to the union of matched category skills from the repository skill set (`frontend`, `java-web`, `python`, `database`, `release`).
     - Risk resolves to `High` and default test tier escalates to the most stringent tier (e.g., Tier 1 + Tier 3 resolves to `Tier 3`).
     - Triggers mandatory `ESCALATE` and halts for human confirmation.

---

## 3. Mandatory Escalation Policy (No Guessing)

To maintain safety and eliminate speculative behavior, the workflow enforces explicit halting:

- **Explicit ESCALATE Outcome**:
  - Tasks that are **ambiguous**, **contradictory**, or have **unknown scope** MUST produce an explicit `ESCALATE` outcome and halt immediately for human clarification.
  - Tasks in any **High-Risk Category** (`DATABASE`, `AUTH_SECURITY`, `UPLOAD_FILE`, `RELEASE`, `MIXED`) or with explicit `RISK: High` / `RISK: Critical` MUST produce an explicit `ESCALATE` outcome and halt immediately for human confirmation.
  - **No Fallback Guessing**: The assistant must NEVER guess, assume missing intent, or default to `MODE: AUDIT` as a silent workaround. It must explicitly report `ESCALATE` and halt.
- **Provisional Context Only**:
  - Inferred category, agents, skills, and tiers serve strictly as provisional context to inform the human engineer during escalation; they never grant authorization to modify code, run mutations, or execute tasks.
- **Optional Repository Context**:
  - Project context documentation (such as `.ai/CONTEXT.md`) is completely optional. If absent, the workflow inspects standard source files directly without making any AI-specific project assumptions.
- **Output Mapping on Halting**:
  - When classification returns `ESCALATE`, the standard response uses `STATUS: BLOCKED` and `NEXT` requests human clarification or confirmation.

---

## 4. Minimal Quick Task Input Contract

Minimal daily tasks require only two inputs:

```text
PROJECT: <path>
TASK: <goal>
```

Optional overrides:
```text
RISK: [Optional: Low | Medium | High | Critical]
ALLOWLIST: [Optional: comma-separated permitted file paths or globs]
CONSTRAINTS: [Optional: specific boundaries or non-goals]
```

### Inferred Execution Parameters

When minimal input is received, the workflow automatically derives provisional context:

- **Category**: Deterministically matched using path and normalized keyword signatures.
- **MODE**: Inferred from category default `MODE` (provisional only; when classification returns `ESCALATE`, execution halts and standard response reports `STATUS: BLOCKED`).
- **RISK**: Inferred from category default `RISK` unless overridden by explicit `RISK:`. High/Critical triggers `ESCALATE`.
- **Agents**: Assigned from category recommended agents.
- **Skills**: Inferred from category recommended skills (using only repository-observed skills, optionally guided by repository file inspection or optional `.ai/CONTEXT.md` if present).
- **Test Tier**: Derived from category default test tier per `core/TEST_POLICY.md`.
- **Allowlist**: Bounded to referenced paths or project workspace.
- **Constraints**: Framework baseline invariants apply automatically.

---

## 5. Absolute Safety Invariants

Task classification serves solely to organize provisional context and choose appropriate verification depth. It carries strict non-negotiable boundaries:

- **No Mutating Git Permissions**: Classification NEVER grants permission for `git add`, `git commit`, `git push`, `git tag`, `git reset`, `git restore`, or `git clean`.
- **No Deployment or Publishing**: Classification NEVER authorizes automated deployments or remote package publication.
- **No Destructive Database Operations**: Classification NEVER authorizes destructive database actions, including `DROP TABLE`, `TRUNCATE`, data-wiping scripts, or irreversible schema mutations.
- **Human Git Boundary**: All staging, committing, pushing, and branch lifecycle events remain exclusive human actions.
- **Mandatory Repository Verification Gate**: Before reporting task completion, the AI assistant must execute:
  1. `git status --short`
  2. `git diff --name-only`
  3. `git diff --check`
  Authoritative priority order: `actual workspace > git diff > worker artifacts`.

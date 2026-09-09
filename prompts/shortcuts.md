# Workflow Shortcut Prompts

Compact user-facing shortcuts that map directly to the framework's canonical policies and deterministic task classification.

---

## 1. Minimal Shortcut Contract

Every shortcut invokes the workflow using minimal input:

### Normal Shortcut Form
```text
<shortcut>
PROJECT: <path>
TASK: <goal>
```
Or in single-line format: `<shortcut> PROJECT: <path> TASK: <goal>`.

### Specialized Input Forms
- Normal shortcuts use `PROJECT` plus `TASK`.
- `/debug` accepts `ISSUE: <description>` (interchangeable with `TASK:`).
- `/audit` accepts `SCOPE: <description>` (interchangeable with `TASK:`).
- `/release` supports project-only invocation (`/release PROJECT: <path>`) for project-level release verification, or with `TASK:` for milestone validation.

### Optional Overrides
```text
RISK: [Optional: Low | Medium | High | Critical]
ALLOWLIST: [Optional: comma-separated file paths or glob patterns]
CONSTRAINTS: [Optional: specific restrictions or boundaries]
```

Omitted parameters (`MODE`, `RISK`, `CATEGORY`, `AGENTS`, `SKILLS`, and `GATES`) are automatically resolved via canonical policies:
- Category & parameter inference: [`core/TASK_CLASSIFICATION.md`](../core/TASK_CLASSIFICATION.md)
- Operational boundaries & agent rules: [`core/AGENT_RULES.md`](../core/AGENT_RULES.md)
- Testing tiers and verification gates: [`core/TEST_POLICY.md`](../core/TEST_POLICY.md)
- Version control governance: [`core/GIT_POLICY.md`](../core/GIT_POLICY.md)
- Quick task specification: [`core/QUICK_TASK_TEMPLATE.md`](../core/QUICK_TASK_TEMPLATE.md)
- Project stack & context: optional `.ai/CONTEXT.md` (when present in target project).

---

## 2. Shortcut Mapping Directory

| Shortcut | Target Intent | Default Category | Inferred MODE | Recommended Agents | Recommended Skills | Default Test Tier |
|---|---|---|---|---|---|---|
| `/fix` | `DEBUG` intent | `DEBUG` | `DEBUG` | `developer.md`, `tester.md`, `reviewer.md` | Stack-derived (`java-web`, `python`, `frontend`, `database`) | `Tier 2` |
| `/feature` | Feature enhancement / implementation | Deferred (`core/TASK_CLASSIFICATION.md`) | `IMPLEMENT` | Deferred (`core/TASK_CLASSIFICATION.md`) | Deferred (`core/TASK_CLASSIFICATION.md`) | Deferred (`core/TASK_CLASSIFICATION.md`) |
| `/debug` | `DEBUG` intent | `DEBUG` | `DEBUG` | `developer.md`, `tester.md`, `reviewer.md` | Stack-derived (`java-web`, `python`, `frontend`, `database`) | `Tier 2` |
| `/audit` | Read-only inspection / audit | Deferred (`core/TASK_CLASSIFICATION.md`) | `AUDIT` | Deferred (`core/TASK_CLASSIFICATION.md`) | Deferred (`core/TASK_CLASSIFICATION.md`) | Deferred (`core/TASK_CLASSIFICATION.md`) |
| `/review` | Independent review / diff inspection | Deferred (`core/TASK_CLASSIFICATION.md`) | `REVIEW` | Deferred (`core/TASK_CLASSIFICATION.md`) | Deferred (`core/TASK_CLASSIFICATION.md`) | Deferred (`core/TASK_CLASSIFICATION.md`) |
| `/test` | `TESTING` intent | `TESTING` | `IMPLEMENT` | `tester.md`, `developer.md` | Stack-derived (`java-web`, `python`, `frontend`) | `Tier 2` |
| `/release` | `RELEASE` intent & `RELEASE_CHECK` | `RELEASE` | `RELEASE_CHECK` | `architect.md`, `tester.md`, `reviewer.md` | `release` | `Tier 4` |
| `/ui` | `UI` intent | `UI` | `IMPLEMENT` | `developer.md`, `reviewer.md` | `frontend` | `Tier 1` |
| `/db` | `DATABASE` intent | `DATABASE` | `IMPLEMENT` | `developer.md`, `architect.md`, `reviewer.md` | `database` | `Tier 3` |
| `/security` | `AUTH_SECURITY` intent | `AUTH_SECURITY` | `IMPLEMENT` | `security.md`, `developer.md`, `reviewer.md` | Stack-derived (`java-web`, `python`, `database`) | `Tier 3` |

---

## 3. Shortcut Execution Rules

1. **Deterministic Resolution & Canonical Authority**:
   - The shortcut sets the target intent and mode where defined (`DEBUG`, `IMPLEMENT`, `AUDIT`, `REVIEW`, `RELEASE_CHECK`).
   - Canonical classification in [`core/TASK_CLASSIFICATION.md`](../core/TASK_CLASSIFICATION.md) remains authoritative. For `/feature`, `/audit`, and `/review`, category, risk, agents, skills, and test tier are deferred to `core/TASK_CLASSIFICATION.md` based on task/scope/path.
   - For all shortcuts, specific paths in `ALLOWLIST:` or `TASK:` refine classification per canonical rules.
   - Skills are derived strictly from repository-observed skills (`frontend`, `java-web`, `python`, `database`, `release`) and optional project `.ai/CONTEXT.md` when present.
2. **Mandatory Halting on Escalation**:
   - Any ambiguous, contradictory, or unknown-scope task MUST produce an explicit `ESCALATE` outcome and halt immediately for human clarification.
   - High-risk escalation depends on the classifier's resulting high-risk category (`DATABASE`, `AUTH_SECURITY`, `UPLOAD_FILE`, `RELEASE`, `MIXED` per `core/TASK_CLASSIFICATION.md`) or explicit `RISK: High`/`Critical`, not solely on shortcut names. Any such task MUST produce an explicit `ESCALATE` outcome and halt for human confirmation before modifying files or executing risky operations.
   - When execution halts on `ESCALATE`, the agent reports standard `STATUS: BLOCKED` and requests human instructions under `NEXT:`.
3. **Absolute Safety Boundaries**:
   - Shortcuts NEVER grant permission for `git add`, `git commit`, `git push`, `git tag`, deployment, destructive database operations (`DROP`, `TRUNCATE`), secret access, or modifications outside the assigned project.
   - Version control mutations remain strictly under the human Git boundary ([`core/GIT_POLICY.md`](../core/GIT_POLICY.md)).
   - The mandatory repository verification gate (`git status --short`, `git diff --name-only`, `git diff --check`) must execute before reporting completion.

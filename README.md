## Daily Usage

For rapid daily handoff, the framework provides 10 compact workflow shortcuts documented in `prompts/shortcuts.md`: `/fix`, `/feature`, `/debug`, `/audit`, `/review`, `/test`, `/release`, `/ui`, `/db`, `/security`.

Shortcuts use minimal input:

```text
PROJECT: <PROJECT_PATH>
TASK: <goal>
```

Optional:

```text
RISK:
ALLOWLIST:
CONSTRAINTS:
```

Execution parameters (`MODE`, `RISK`, `AGENTS`, `SKILLS`, `GATES`) are derived through canonical policies:

- `core/TASK_CLASSIFICATION.md`
- `core/TEST_POLICY.md`
- `core/AGENT_RULES.md`
- `core/GIT_POLICY.md`
- optional project `.ai/CONTEXT.md`

High-risk tasks, ambiguous scope, contradictory requirements, or destructive operations must escalate before execution.

### Examples

```text
/fix PROJECT: <PROJECT_PATH> TASK: Fix avatar upload

/ui PROJECT: <PROJECT_PATH> TASK: Improve navbar spacing

/audit PROJECT: <PROJECT_PATH> SCOPE: authentication

/release PROJECT: <PROJECT_PATH>
```

Safety invariants:

- Shortcuts never grant permission for `git add`, `git commit`, `git push`, `git tag`, deployment, destructive database operations, or secret access.
- Human engineer remains the authority for Git operations and release decisions.
- Repository verification is mandatory before completion.

The mandatory repository verification gate:

```powershell
git status --short
git diff --name-only
git diff --check
```

must execute before reporting completion.

---

## Standard Output Format

All AI responses must conclude with or conform to:

```text
STATUS: <COMPLETED | IN_PROGRESS | WARNING | BLOCKED | FAILED>
CHANGED: <Comma-separated list of modified files, or NONE>
TEST: <Executed test commands and summary of results>
RISK: <Identified risks, regressions, or assumptions>
NEXT: <Recommended next action>
```

---

## Basic Usage

### 1. Define Project Context (Optional)

If desired, copy:

```text
core/PROJECT_CONTEXT_TEMPLATE.md
```

to:

```text
.ai/CONTEXT.md
```

inside the target project.

Project context documents stack details, architecture, and constraints without introducing AI-specific assumptions.

Run:

```powershell
./scripts/load-context.ps1 -ProjectPath "<PROJECT_PATH>"
```

to inspect project context and suggested skills.

---

### 2. Define the Task

Use either:

- `core/QUICK_TASK_TEMPLATE.md` for normal daily tasks
- `core/TASK_TEMPLATE.md` for detailed tasks

The workflow derives missing execution parameters through deterministic classification rules.

---

### 3. Select Execution Mode

Use the corresponding prompt template:

```text
prompts/
```

Examples:

- `implement.md`
- `debug.md`
- `audit.md`
- `review.md`
- `release.md`

---

### 4. Inspect Before Editing

AI must:

- inspect existing behavior
- understand project structure
- verify impact scope
- identify risks

before modifying files.

---

### 5. Execute and Test

Changes must:

- stay inside the approved allowlist
- follow minimal-change principles
- execute the required test tier from `core/TEST_POLICY.md`

---

### 6. Read-Only Verification

Use workflow validation scripts:

```text
scripts/
├── git-check.ps1
├── diff-check.ps1
├── release-check.ps1
└── workflow-check.ps1
```

These scripts verify:

- Git state
- modification boundaries
- release readiness
- workflow integrity

---

### 7. Human Review and Git Operations

The human engineer performs:

- final diff review
- `git add`
- `git commit`
- `git push`
- release decisions

AI agents must not perform automatic Git mutations.

---

## Workflow Health Check

Run:

```powershell
./scripts/workflow-check.ps1
```

The health check validates:

- required folders
- required workflow files
- shortcut definitions
- skill integrity
- agent integrity
- documentation references
- external path issues

Output format:

```text
PASS:
FAIL:
WARN:
NEXT:
```

Exit codes:

```text
0  = workflow healthy
1  = required component failure
```

A healthy workflow repository should have:

```text
FAIL:
None

WARN:
None
```
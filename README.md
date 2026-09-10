## Provider Routing & Canonical Contract

Tasks route across three providers (Native Codex, ChatWeb, Antigravity) governed by the canonical six-field contract and provider routing defined in [`core/TASK_TEMPLATE.md`](core/TASK_TEMPLATE.md) and procedure in [`core/TASK_CLASSIFICATION.md`](core/TASK_CLASSIFICATION.md).

Provider boundary:

- **Native Codex**: read-only analysis and verification, plus documentation/non-executable artifact writes only.
- **ChatWeb**: planning and trade-off analysis only; no file modifications.
- **Antigravity**: all behavior-changing repository modifications, including single-file source, test, UI, runtime, configuration, and dependency changes.

> [!IMPORTANT]
> The Antigravity bridge is required **only** for Antigravity work. Missing or uncertain Antigravity readiness blocks **only** that lane; Native Codex and ChatWeb lanes continue unaffected.

### Daily Usage & Shortcuts

For rapid daily handoff, the framework provides 10 compact workflow shortcuts documented in [`prompts/shortcuts.md`](prompts/shortcuts.md): `/fix`, `/feature`, `/debug`, `/audit`, `/review`, `/test`, `/release`, `/ui`, `/db`, `/security`.

Shortcuts serve as thin compatibility aliases that map directly into the canonical fields (`INTENT`, `RISK`, `TARGET`, `ALLOWLIST`, `REVIEW`, `TEST`):

```text
<shortcut>
INTENT: <objective>
RISK: <Low | Medium | High | Critical>
TARGET: <project-path>
ALLOWLIST: <mandatory for writes, or NONE>
REVIEW: <SELF | PEER | HUMAN>
TEST: <focused verification command, tier, or evidence>
```
Shorthand inputs expand deterministically to all six canonical fields using row defaults from [`prompts/shortcuts.md`](prompts/shortcuts.md) for `RISK`, `REVIEW`, and `TEST` (`ALLOWLIST: NONE` for read-only aliases; missing write `ALLOWLIST` blocks execution).

### Safety Invariants & Governance

- **Write Allowlists**: Explicit and mandatory for all write tasks. Modifying files outside the allowlist is prohibited.
- **Human Authority**: Human engineers hold exclusive authority for `git add`, `git commit`, `git push`, `git tag`, deployments, and releases ([`core/GIT_POLICY.md`](core/GIT_POLICY.md)).
- **Repository Verification Gate**: Before completing any task, execute `git status --short`, `git diff --name-only`, and `git diff --check` (priority: `actual workspace > git diff > worker artifacts`; if mismatch, report `STATUS: FAIL` or `STATUS: UNVERIFIED`).

---

## Standard Output Format

All AI responses must conclude with or conform to:

```text
STATUS: <PASS | FAIL | BLOCKED | UNVERIFIED>
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

For deterministic Phase 2.1 project memory context loading, run:

```powershell
./scripts/context-loader.ps1 -Project "<PROJECT>" -Task "<TASK_DESCRIPTION>"
```

to select and load project memory files (`projects/<project>/*.md`) based on task classification or manual `@load` overrides.

---

### 2. Define the Task

Use:

- `core/TASK_TEMPLATE.md` for the canonical routing contract
- `core/QUICK_TASK_TEMPLATE.md` as a thin compatibility alias for quick handoffs

The workflow routes tasks deterministically based on [`core/TASK_CLASSIFICATION.md`](core/TASK_CLASSIFICATION.md).

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
- execute focused tests matching the required tier from `core/TEST_POLICY.md`

---

### 6. Read-Only Verification

Use workflow validation scripts:

```text
scripts/
├── bridge-check.ps1
├── context-loader-check.ps1
├── context-loader.ps1
├── diff-check.ps1
├── git-check.ps1
├── load-context.ps1
├── release-check.ps1
├── start-antigravity.ps1
└── workflow-check.ps1
```

These scripts verify:

- Git state
- modification boundaries
- release readiness
- workflow integrity
- bridge readiness

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

## Before delegating tasks to Antigravity

The bridge is required **only** for Antigravity work. Before delegating tasks to Antigravity, ensure the bridge session is active, healthy, and verified:

1. **Launch or verify Antigravity bridge**:
   ```powershell
   .\scripts\start-antigravity.ps1
   ```
   This ensures `Antigravity.exe` is running with `--remote-debugging-port=9222` and waits until TCP port 9222 is listening without altering the installation.

2. **Verify bridge readiness**:
   ```powershell
   .\scripts\bridge-check.ps1
   ```
   Confirm that the check outputs `STATUS: PASS (READY)`.

3. **Submit jobs**:
   Submit tasks or delegate jobs to Antigravity only after verifying bridge `PASS`.
   Per `core/BRIDGE_POLICY.md`, job submission is prohibited when the bridge is in a `FAILED` or `STALE` state.

4. **Bridge Recovery**:
   If the bridge check fails or returns warnings, follow the recovery procedures and fresh-Codex-session recovery steps defined in `core/BRIDGE_POLICY.md`:
   - If `FAILED`: run `.\scripts\start-antigravity.ps1` to ensure port 9222 is open, then re-check with `.\scripts\bridge-check.ps1`.
   - If `STALE`: reset or restart the session and verify readiness before submitting jobs.

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

---

## Pre-Release Gate Check

Run:

```powershell
./scripts/release-check.ps1 -SafeMode
```

For release candidate gate verification:

```powershell
.\scripts\release-check.ps1 -RepoPath "<project-path>" `
    -RequireClean `
    -RequireBranch "main" `
    -TestTier 4 `
    -TestEvidence "PASS (all tests passed)" `
    -ArtifactPath "dist/app.jar" `
    -SmokeEvidence "PASS (smoke verified)"
```

The release check enforces:

- `GIT_VALIDATION`: repository validity, target commit SHA, branch match, clean working tree, and detection of unexpected untracked release files/binaries with exit code checks.
- `BUILD_VALIDATION`: build tool and wrapper availability (Maven wrapper `mvnw`); validates build execution only when explicitly requested via `-ValidateBuild` with verifiable `-BuildEvidence` (fails closed if absent).
- `TEST_VALIDATION`: enforces declared `TestTier` (Tier 0 to 4) and distinguishes `SKIPPED` from `PASSED`.
- `ARTIFACT_VALIDATION`: validates explicit artifact path, regular file existence, supported format, non-zero size, and SHA-256 checksum.
- `RUNTIME_VALIDATION`: verifies smoke test evidence; normal release gates block (`exit 1`) when runtime is `UNVERIFIED` (SafeMode remains non-blocking without claiming all gates passed).

Output sections:

```text
SOURCE_VALIDATION: PASS | FAIL
ARTIFACT_VALIDATION: PASS | FAIL
RUNTIME_VALIDATION: VERIFIED | UNVERIFIED
```

Final release decisions, Git tagging, and production deployments remain exclusively the human engineer's responsibility.

# Structured Task Handoff Workflow

This document defines the structured handoff workflow for coordinating task delegation across AI providers and the human engineer within the workflow framework.

---

## 1. When a Handoff is Created

A structured handoff record is created when:
- **Cross-Provider Task Delegation**: Work transitions between providers (e.g., User to Native Codex, ChatWeb to Antigravity, or Native Codex to Antigravity).
- **Behavior-Changing Repository Implementation**: A diagnosed bug, feature request, or schema change requires Antigravity execution with an explicit allowlist.
- **Multi-Phase Development**: Work spans diagnosis, planning, execution, and verification phases requiring durable state tracking.
- **Two-Phase Defect Fixing**: Native Codex completes read-only diagnosis (`/fix`) and hands off implementation to Antigravity.

---

## 2. Provider Responsibilities

Each participant in the handoff workflow operates strictly within defined authority boundaries:

- **User**:
  - Defines the core intent, requirements, and constraints.
  - Reviews and approves write allowlists, architectural decisions, and high/critical risk classifications.
  - Holds exclusive authority over all Git lifecycle actions (`git add`, `git commit`, `git push`, `git tag`), releases, and deployments ([`core/GIT_POLICY.md`](../core/GIT_POLICY.md)).

- **ChatWeb**:
  - Interactive requirements clarification, architectural trade-off analysis, and cross-project scope alignment.
  - Prepares task scope and drafts initial handoff fields without modifying workspace files.
  - Never writes to disk or executes commands.

- **Native Codex**:
  - Performs read-only repository discovery, code inspection, and diagnosis.
  - Creates or updates non-executable documentation artifacts (including handoff Markdown records).
  - Prepares structured handoffs for delegated execution.
  - Strictly prohibited from making behavior-changing repository edits.

- **Antigravity**:
  - Executes approved behavior-changing repository modifications within the designated `ALLOWLIST`.
  - Verifies bridge session readiness (`STATUS: PASS (READY)`) prior to execution.
  - Executes focused tests matching the required test tier ([`core/TEST_POLICY.md`](../core/TEST_POLICY.md)).
  - Records verification evidence, artifacts, and diff summaries in the designated evidence directory.

---

## 3. Lifecycle States and Classification Model

Task handoffs clearly separate task lifecycle progression, validation results, and task closure outcome.

### Lifecycle States

Every handoff tracks progress through seven deterministic lifecycle states in `META.STATE`:

1. **`CREATED`**: Handoff record created with initial task metadata and intent. Scope and target identified.
2. **`READY`**: All nine required sections, including `META`, are populated; the allowlist is verified and an executor is assigned. Ready for pickup.
3. **`EXECUTING`**: The assigned executor is actively performing the approved work within the allowlist.
4. **`VERIFYING`**: Implementation complete. Focused test suites and validation commands are running; test results and diff evidence are being collected in the evidence directory.
5. **`AWAITING_APPROVAL`**: Verification complete; awaiting human review or authorization prior to completion (e.g., for high/critical risk classifications or waived test failures).
6. **`COMPLETED`**: All acceptance criteria satisfied, verification validated, and evidence recorded. Terminal success state.
7. **`FAILED`**: Work blocked, allowlist violated, verification failed without waiver, or unrecoverable error encountered. Terminal failure state until a new handoff is initiated.

#### State Transitions

```text
CREATED -> READY -> EXECUTING -> VERIFYING -> AWAITING_APPROVAL -> COMPLETED
   │         │          │           │               │
   └─────────┴──────────┴───────────┴───────────────┴─────────> FAILED
```

Any active state may transition to `FAILED` if execution or verification fails. A failed handoff is terminal.

For `VERIFYING`, `AWAITING_APPROVAL`, `COMPLETED`, and `FAILED`, `scripts/handoff-check.ps1` requires `-EvidenceDir` to point to an existing evidence directory. Earlier states may omit it; the validator never creates the directory. Task closure evidence is verified using `scripts/evidence-check.ps1`.

### Validation Results

Independent of lifecycle state, verification results are strictly classified as:

- **`PASS`**: All required validation commands, unit/integration suites, and contract checks passed completely.
- **`FAIL`**: One or more validation checks failed.
- **`BLOCKED`**: Validation cannot proceed due to external blockers, missing environment prerequisites, or infrastructure failure.
- **`UNVERIFIED`**: Changes have not yet been evaluated against the validation suite.

### Outcome

Task closure outcome classifies how the task reached completion:

- **`NORMAL`**: Standard execution where all acceptance criteria and verification tests passed without exceptions or waivers.
- **`WAIVED`**: Execution completed with one or more documented, isolated, and accepted failure waivers for pre-existing or out-of-scope issues. All waivers must include root cause diagnosis and evidence that the failure is unrelated to current task changes.

---

## 4. Contract Reference

Task handoff files use the canonical contract in [`handoffs/templates/task-handoff-template.md`](../handoffs/templates/task-handoff-template.md). Keep field definitions there; this workflow only defines when the contract is used and how it moves through lifecycle states.

Use [`scripts/handoff-check.ps1`](../scripts/handoff-check.ps1) to validate handoff Markdown files against this contract.
Use [`scripts/evidence-check.ps1`](../scripts/evidence-check.ps1) to validate evidence directory artifacts, JSON validity, task consistency, scope adherence, and test consistency.

### Evidence Validation Checks

Task closure evidence in `handoffs/completed/<task-id>/` (or active verification directories) is validated by `scripts/evidence-check.ps1`:

1. **Artifact Validation**: Confirms presence and completeness of `status.json`, `result.md`, `changed-files.txt`, `diff.patch`, and `test-output-summary.md` (when required).
2. **JSON Validation**: Confirms `status.json` parses successfully and provides required properties (`task`, `status`).
3. **Consistency Validation**: Confirms task ID matches across handoff metadata and evidence, validation status is explicit (`PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED`), and outcome is reconciled (`NORMAL`, `WAIVED`).
4. **Scope Validation**: Confirms `changed-files.txt` matches `diff.patch` changes, and all changed files adhere to the task's `ALLOWLIST` and forbidden scopes.
5. **Test Validation**: Confirms test counts in `test-output-summary.md` and `status.json` are internally consistent and reconciles failure waivers.

Output produces a deterministic status (`PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED`) and five check results.

---

## 5. Explicit Non-Goals

The handoff workflow is strictly a lightweight, file-based coordination mechanism. It explicitly rejects:
- **No Database**: No database, vector store, document database, or persistent storage service.
- **No Dashboard or Server**: No web portal, status dashboard, daemon, or background HTTP server.
- **No Agent Orchestration Engine**: No autonomous multi-agent orchestration, auto-dispatch, or scheduler.
- **No Task Queue Services**: No background message queue, pub/sub system, or polling workers.
- **No Automatic Git Actions**: No automated commits, staging, branches, or tags.

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

Every handoff tracks progress through exactly six unified lifecycle states in `META.STATE`:

1. **`CREATED`**: Handoff record or execution request created with initial metadata, intent, explicit target workspace, and allowlist.
2. **`SUBMITTED`**: Execution request validated and dispatched/submitted to the designated executor (e.g. Antigravity bridge queue) with explicit task ID, workspace, executor, and artifact location.
3. **`RUNNING`**: The assigned executor is actively performing the approved work within the allowlist.
4. **`ARTIFACT_READY`**: Implementation complete. Required evidence artifacts (`result.md`, `changed-files.txt`, `diff.patch`, `test-output-summary.md`, `status.json`) have been generated in the designated artifact directory. Antigravity produces artifacts and stops at this state only.
5. **`VERIFIED`**: Artifacts and test outputs evaluated by the orchestrator (Codex) and validators. Verification status (`PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED`) is recorded. The Codex golden-path verifier (`scripts/bridge-golden-path-check.ps1`) is the only path that advances a job to `VERIFIED`, stamping durable provenance (`verifiedBy: "codex"`).
6. **`CLOSED`**: Terminal lifecycle state reached following successful verification and any required human review or authorization. `CLOSED` is reached only via guarded Codex transition from `VERIFIED` with durable provenance (`closedBy: "codex"`). Self-reported or forged closure without Codex provenance fails closed.

#### State Transitions

```text
CREATED -> SUBMITTED -> RUNNING -> ARTIFACT_READY -> VERIFIED -> CLOSED
```

For `ARTIFACT_READY`, `VERIFIED`, and `CLOSED`, `scripts/handoff-check.ps1` requires `-EvidenceDir` to point to an existing evidence directory containing the generated artifacts. Earlier states may omit it; the validator never creates the directory. Task closure evidence is verified using `scripts/evidence-check.ps1`.

> [!IMPORTANT]
> Lifecycle state is strictly separated from validation outcome. Failures or blockers during verification do not introduce conflicting legacy state names; they are recorded in the validation result (`PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED`) and task outcome (`NORMAL`, `WAIVED`).

### Validation Results

Independent of lifecycle state, verification results are strictly classified as:

- **`PASS`**: All required validation commands, unit/integration suites, and contract checks passed completely (or completed under an explicit documented waiver where raw tests reported isolated pre-existing failures reconciled with waiver proof).
- **`FAIL`**: One or more validation checks failed without an accepted waiver.
- **`BLOCKED`**: Validation cannot proceed due to external blockers, missing environment prerequisites, or infrastructure failure.
- **`UNVERIFIED`**: Changes have not yet been evaluated against the validation suite.

### Outcome

Task closure outcome classifies how the task reached completion:

- **`NORMAL`**: Standard execution where all acceptance criteria and verification tests passed without exceptions or waivers.
- **`WAIVED`**: Execution completed with one or more documented, isolated, and accepted failure waivers for pre-existing or out-of-scope issues. All waivers must include root cause diagnosis and evidence that the failure is unrelated to current task changes. A raw test summary may report `FAIL`, but evidence validation yields `PASS` with outcome `WAIVED` only when `status.json` contains the explicit `WAIVED` outcome and complete waiver proof; otherwise validation fails closed.

---

## 4. Contract Reference

Task handoff files use the canonical contract in [`handoffs/templates/task-handoff-template.md`](../handoffs/templates/task-handoff-template.md). Keep field definitions there; this workflow only defines when the contract is used and how it moves through lifecycle states.

Use [`scripts/handoff-check.ps1`](../scripts/handoff-check.ps1) to validate handoff Markdown files against this contract.
Use [`scripts/evidence-check.ps1`](../scripts/evidence-check.ps1) to validate evidence directory artifacts, JSON validity, task consistency, scope adherence, and test consistency.

### Evidence Validation Checks

Task closure evidence in `handoffs/completed/<task-id>/` (or active verification directories) is validated by `scripts/evidence-check.ps1`:

1. **Artifact Validation**: Confirms presence and completeness of `status.json`, `result.md`, `changed-files.txt`, `diff.patch`, and `test-output-summary.md` (when required). For bridge jobs, `request.md` is required and non-empty. Handoffs in execution states must declare an explicit `Artifact Directory` or artifact location under `EVIDENCE`.
2. **JSON Validation**: Confirms `status.json` parses successfully and provides required properties (`task`/`jobId`, `status`/`validation`). For bridge jobs, `status.json` is the authoritative execution envelope enforcing explicit task ID, absolute workspace, `executor=antigravity`, `routingDecision=DELEGATED` (never `DIRECT`), non-`DIRECT` `workflowMode`, artifact location, and canonical lifecycle state fail-closed. Validates optional Phase 3.1 observability metadata (`context.loadedFiles`, UTF-8 `context.sizeBytes`, `handoff.requestBytes`, `performance`, `validation`) when present, while keeping historical jobs without observability fully valid.
3. **Consistency Validation**: Confirms task ID matches across handoff metadata and evidence, validation status is explicit (`PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED`), and outcome is reconciled (`NORMAL`, `WAIVED`). For bridge jobs, `status.json` is authoritative for envelope metadata while `request.md` provides the compact task body (Goal, Intent, Scope, Acceptance Criteria, Tests) without redundant envelope requirements, and requires durable Codex provenance (`verifiedBy: "codex"`, `closedBy: "codex"`) for `VERIFIED` and `CLOSED` states.
4. **Scope Validation**: Confirms `changed-files.txt` matches `diff.patch` changes, and all changed files adhere to the task's `ALLOWLIST` and forbidden scopes.
5. **Test Validation**: Confirms test counts in `test-output-summary.md` and `status.json` are internally consistent and reconciles failure waivers. When raw tests fail, requires explicit `outcome: "WAIVED"` and complete waiver proof in `status.json`.

Output produces a deterministic status (`PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED`) and five check results.

---

## 5. Explicit Non-Goals

The handoff workflow is strictly a lightweight, file-based coordination mechanism. It explicitly rejects:
- **No Database**: No database, vector store, document database, or persistent storage service.
- **No Dashboard or Server**: No web portal, status dashboard, daemon, or background HTTP server.
- **No Agent Orchestration Engine**: No autonomous multi-agent orchestration, auto-dispatch, or scheduler.
- **No Task Queue Services**: No background message queue, pub/sub system, or polling workers.
- **No Automatic Git Actions**: No automated commits, staging, branches, or tags.

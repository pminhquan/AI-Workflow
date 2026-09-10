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

## 3. Lifecycle States

Every handoff tracks its progress through six deterministic lifecycle states in `META.STATE`:

1. **`CREATED`**: Handoff record created with initial task metadata and intent. Scope and target identified.
2. **`READY`**: All nine required sections, including `META`, are populated; the allowlist is verified and an executor is assigned. Ready for pickup.
3. **`EXECUTING`**: The assigned executor is actively performing the approved work within the allowlist.
4. **`VERIFYING`**: Implementation complete. Focused test suites and validation commands are running; test results and diff evidence are being collected in the evidence directory.
5. **`COMPLETED`**: All acceptance criteria satisfied, verification tests pass, and evidence is recorded. Terminal success state.
6. **`FAILED`**: Work blocked, allowlist violated, verification failed, or unrecoverable error encountered. Terminal failure state until a new handoff is initiated.

### State Transitions

```text
CREATED -> READY -> EXECUTING -> VERIFYING -> COMPLETED
   │         │          │           │
   └─────────┴──────────┴───────────┴─────────> FAILED
```

Any active state may transition to `FAILED` if execution or verification fails. A failed handoff is terminal.

For `VERIFYING`, `COMPLETED`, and `FAILED`, `scripts/handoff-check.ps1` requires `-EvidenceDir` to point to an existing evidence directory. Earlier states may omit it; the validator never creates the directory.

---

## 4. Contract Reference

Task handoff files use the canonical contract in [`handoffs/templates/task-handoff-template.md`](../handoffs/templates/task-handoff-template.md). Keep field definitions there; this workflow only defines when the contract is used and how it moves through lifecycle states.

Use [`scripts/handoff-check.ps1`](../scripts/handoff-check.ps1) to validate handoff Markdown files against this contract.

---

## 5. Explicit Non-Goals

The handoff workflow is strictly a lightweight, file-based coordination mechanism. It explicitly rejects:
- **No Database**: No database, vector store, document database, or persistent storage service.
- **No Dashboard or Server**: No web portal, status dashboard, daemon, or background HTTP server.
- **No Agent Orchestration Engine**: No autonomous multi-agent orchestration, auto-dispatch, or scheduler.
- **No Task Queue Services**: No background message queue, pub/sub system, or polling workers.
- **No Automatic Git Actions**: No automated commits, staging, branches, or tags.

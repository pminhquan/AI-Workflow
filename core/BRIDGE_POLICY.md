# Antigravity Bridge & Session Reliability Policy

This policy governs task delegation, bridge health, and session lifecycle between Codex and Antigravity within the AI-assisted workflow.

## 1. Core Invariant & Delegation Gate

1. **Antigravity-Only Requirement**: The Antigravity bridge is required **only** for Antigravity work: all behavior-changing repository modifications, including single-file changes, source, tests, UI/runtime, dependencies, configuration, schema, security, upload, and release work. Native Codex handles only read-only analysis, verification, and documentation/non-executable artifact writes; ChatWeb handles planning. Audit, architecture review, code review, debugging analysis, and validation-only tasks remain Codex-direct (`DIRECT`) and cannot create Antigravity execution jobs unless an implementation step is explicitly requested. Missing or uncertain Antigravity readiness blocks **only** that lane.
2. **Bridge PASS Mandatory for Antigravity**: A passing bridge check (`STATUS: PASS (READY)`) is strictly required before any delegated Antigravity task is initiated.
3. **No Antigravity Job Submission When Unavailable**: No job submission or task offload to Antigravity is permitted when the Antigravity bridge is unavailable, unverified, or in a `FAILED` or `STALE` state.
4. **Pre-Delegation Verification**: Before dispatching tasks to the Antigravity lane:
   - Ensure Antigravity is running and active on its remote debugging port via `scripts/start-antigravity.ps1` (discovering the active port via `DevToolsActivePort` or configured environment).
   - Verify bridge health and endpoint responsiveness via `scripts/bridge-check.ps1`.
   - Block Antigravity lane execution immediately if the bridge readiness status is not `PASS`.

## 2. Execution Request Contract & Runtime Discovery

### Execution Request Contract & Authoritative Envelope
Bridge execution uses `status.json` as the authoritative execution envelope and `request.md` as the compact task body:

1. **Authoritative Envelope (`status.json`)**: Every bridge job requires an explicit, fail-closed `status.json` declaring:
   - **Task Identifier** (`jobId` / `taskId`): Unique, durable identifier tracking the work unit.
   - **Workspace Location** (`workspace`): Absolute path to the authoritative repository workspace (Windows drive or UNC, not unknown/unspecified). Implicit-directory and unknown-workspace assumptions are strictly prohibited.
   - **Assigned Executor** (`executor`): Explicitly set to `antigravity`. Implicit executor routing is prohibited.
   - **Routing Decision** (`routingDecision`) and **Delegated Path** (`workflowMode`): Explicitly set to `routingDecision=DELEGATED` (never `DIRECT`) and a consistent non-`DIRECT` delegated path:
     - `DELEGATED`: Defined as Antigravity implementation plus Codex verification. Standard mode for all behavior-changing repository modifications and normal fixes.
     - `HYBRID`: Permitted only when both Codex analysis/review and Antigravity execution are explicitly required; not permitted for normal fixes.
     Audit, architecture review, code review, debugging analysis, and validation-only tasks remain Codex-direct (`DIRECT`) and cannot create Antigravity execution jobs unless an implementation step is explicitly requested. Missing fields or `DIRECT` routing fail closed on bridge jobs.
   - **Canonical Lifecycle State** (`state` / `lifecycle`): Exactly one of the six unified states (`CREATED`, `SUBMITTED`, `RUNNING`, `ARTIFACT_READY`, `VERIFIED`, `CLOSED`).
   - **Artifact Location** (`resultArtifact`, `resultFile`, `jobFolder`, or `artifactDirectory`): Explicit location where durable evidence artifacts will be published.
2. **Compact Task Body (`request.md`)**: `request.md` serves as a compact task body containing only Goal, Intent, Scope, Acceptance Criteria, and Tests. It remains required and non-empty with enough content for execution. Redundant envelope metadata (workspace, executor, routing, artifact paths, timestamps, or generic bridge instructions) is removed from `request.md` validator and policy requirements. If an external generator still appends envelope metadata to `request.md`, validators tolerate it without requiring it.
3. **Optional Lightweight Observability (`observability`)**: NEW bridge jobs may optionally include structured observability metadata in `status.json` without duplicating existing envelope fields (`jobId`, `routingDecision`, `executor`, `lifecycle`, `validation`):
   - **Context (`context`)**: `loadedFiles` (array of loaded file names) and `sizeBytes` (non-negative UTF-8 byte count of loaded context content; full context content is never stored).
   - **Handoff (`handoff`)**: `requestBytes` (non-negative UTF-8 byte count of the request body).
   - **Performance (`performance`)**: Execution timing when available, including `start`, `end`, and non-negative `durationMs`.
   - **Validation (`validation`)**: `checksExecuted` (count or list of validation checks) and `aggregate` result (`PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED`).
   Historical job artifacts without observability remain fully valid.

### Configured Runtime Discovery & Fail-Closed Port Resolution
Fixed-port assumptions are completely removed. Bridge connection uses deterministic port resolution in the following order:
1. **Explicit Parameter**: `-Port <int>` passed via script invocation or CLI.
2. **Configured Environment**: `$env:ANTIGRAVITY_PORT` or `$env:DEVTOOLS_PORT` if defined.
3. **DevToolsActivePort Discovery**: Inspects candidate files:
   - `%APPDATA%\Antigravity\DevToolsActivePort`
   - `%LOCALAPPDATA%\Antigravity\DevToolsActivePort`
   - `%APPDATA%\Antigravity IDE\DevToolsActivePort`
   Line 1 provides the active listening TCP port; Line 2 provides the browser target path.
4. **Fail-Closed Requirement**: If no port is specified via parameter, environment, or DevToolsActivePort discovery, execution fails closed with a clear diagnostic without probing or launching an implicit fallback port.

## 3. Bridge Readiness States

| State | Definition | Indicators | Permitted Actions |
|---|---|---|---|
| **`READY`** | Bridge fully operational and receptive to commands | - Antigravity process active<br>- TCP remote debugging port in LISTENING state (via runtime discovery or explicit port)<br>- DevTools HTTP endpoint `/json/version` reachable<br>- Active page count > 0 with WebSocket URLs<br>- No stale-session warnings | Job submission and delegation permitted |
| **`STALE`** | Session context disconnected, detached, or wedged | - Process or port active, but page count is 0<br>- DevTools page targets missing `webSocketDebuggerUrl`<br>- Session hung or window in uninitialized/blank state<br>- Previous job submission timed out or returned `submit_failed` | Job submission strictly prohibited; recovery required |
| **`FAILED`** | Bridge endpoint or process completely unreachable | - Antigravity process not running<br>- TCP port not listening<br>- DevTools endpoint connection refused or timed out<br>- `DevToolsActivePort` missing or unreadable | Job submission strictly blocked; startup required |

## 4. Bridge Job Lifecycle & Evidence Contract

Delegated bridge tasks follow the unified six-state lifecycle model:

```text
CREATED -> SUBMITTED -> RUNNING -> ARTIFACT_READY -> VERIFIED -> CLOSED
```

1. **`CREATED`**: Job request instantiated with task ID, workspace, allowlist, and artifact expectations.
2. **`SUBMITTED`**: Request validated and placed into the bridge queue (`.antigravity-bridge/jobs/<job-id>/`).
3. **`RUNNING`**: Antigravity actively executing the allowlisted changes.
4. **`ARTIFACT_READY`**: Execution finished; required durable artifacts (`result.md`, `changed-files.txt`, `diff.patch`, `test-output-summary.md`, `status.json`) are populated in the job folder. Antigravity produces artifacts and stops at this state only.
5. **`VERIFIED`**: Codex orchestrator runs evidence and handoff validators; validation status (`PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED`) is recorded. The Codex golden-path verifier (`scripts/bridge-golden-path-check.ps1`) is the only path that advances `ARTIFACT_READY -> VERIFIED`, stamping durable provenance (`verifiedBy: "codex"`).
6. **`CLOSED`**: Terminal task closure following verification and human authorization. `CLOSED` is reached only via guarded Codex transition from `VERIFIED` with durable provenance (`closedBy: "codex"`). Self-reported or forged `CLOSED+PASS` artifacts from Antigravity without Codex provenance fail closed.

> [!NOTE]
> Antigravity produces artifacts and stops at `ARTIFACT_READY` only, never claiming `VERIFIED` or `CLOSED`. Codex-side verification is the sole path that advances a job to `VERIFIED` (`verifiedBy: "codex"`), and `CLOSED` is allowed only after verification succeeds via guarded Codex transition (`closedBy: "codex"`).

## 5. Recovery Procedures

### A. Recovery from `FAILED` State
1. Run `.\scripts\start-antigravity.ps1` to start Antigravity with remote debugging.
2. Wait for the debugging port to enter the LISTENING state.
3. Execute `.\scripts\bridge-check.ps1` to confirm `STATUS: PASS (READY)`.
4. If startup fails, verify the executable path at `C:\Users\My Laptop\AppData\Local\Programs\antigravity\Antigravity.exe` and confirm no port conflicts exist.

### B. Recovery from `STALE` State
1. Do not submit new jobs to a stale session.
2. Inspect the running Antigravity window to ensure the active workspace is loaded and not hung.
3. If the window is unresponsive or page targets remain at 0, close the Antigravity process and run `.\scripts\start-antigravity.ps1`.
4. Re-run `.\scripts\bridge-check.ps1` to ensure `STATUS: PASS (READY)` before submitting any work.

### C. Fresh-Codex-Session Recovery Steps
When a delegated bridge job fails (such as an offload exception, DevToolsActivePort missing error, or websocket drop):
1. **Halt Submissions**: Stop all queued delegations immediately.
2. **Inspect Bridge Status**: Run `.\scripts\bridge-check.ps1` to diagnose whether the issue is process absence, port listening failure, or target disconnection.
3. **Restart Bridge Service**: If port is not listening, launch or relaunch Antigravity via `.\scripts\start-antigravity.ps1`.
4. **Initiate Fresh Codex Session**: Close or reset the failing Codex session context to clear any poisoned websocket handles, stale task IDs, or broken client state.
5. **Verify Bridge Readiness**: In the fresh session, run `.\scripts\bridge-check.ps1` and verify that the output reports `PASS`.
6. **Resume Delegated Tasks**: Resubmit the task only after the fresh session has verified bridge `PASS`.

## 6. Operational Safety Constraints

- **Human Authority**: Human engineers retain ultimate control over task execution and Git mutations.
- **No Installation Tampering**: AI agents must never modify, delete, or rewrite files inside the Antigravity application directory (`AppData\Local\Programs\antigravity`).
- **No Forceful Process Termination**: Agents must not indiscriminately kill or restart running Antigravity processes unless explicitly instructed by the user or required for critical stale-session recovery.
- **Fail-Closed Safety**: Any ambiguity in bridge readiness must result in a fail-closed response, preventing corrupted task dispatch.

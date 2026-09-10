# Antigravity Bridge & Session Reliability Policy

This policy governs task delegation, bridge health, and session lifecycle between Codex and Antigravity within the AI-assisted workflow.

## 1. Core Invariant & Delegation Gate

1. **Antigravity-Only Requirement**: The Antigravity bridge is required **only** for Antigravity work: all behavior-changing repository modifications, including single-file changes, source, tests, UI/runtime, dependencies, configuration, schema, security, upload, and release work. Native Codex handles only read-only analysis, verification, and documentation/non-executable artifact writes; ChatWeb handles planning. Missing or uncertain Antigravity readiness blocks **only** that lane.
2. **Bridge PASS Mandatory for Antigravity**: A passing bridge check (`STATUS: PASS (READY)`) is strictly required before any delegated Antigravity task is initiated.
3. **No Antigravity Job Submission When Unavailable**: No job submission or task offload to Antigravity is permitted when the Antigravity bridge is unavailable, unverified, or in a `FAILED` or `STALE` state.
4. **Pre-Delegation Verification**: Before dispatching tasks to the Antigravity lane:
   - Ensure Antigravity is active on port 9222 via `scripts/start-antigravity.ps1`.
   - Verify bridge health and endpoint responsiveness via `scripts/bridge-check.ps1`.
   - Block Antigravity lane execution immediately if the bridge readiness status is not `PASS`.


## 2. Bridge Readiness States

| State | Definition | Indicators | Permitted Actions |
|---|---|---|---|
| **`READY`** | Bridge fully operational and receptive to commands | - Antigravity process active<br>- TCP port 9222 in LISTENING state<br>- DevTools HTTP endpoint `/json/version` reachable<br>- Active page count > 0 with WebSocket URLs<br>- No stale-session warnings | Job submission and delegation permitted |
| **`STALE`** | Session context disconnected, detached, or wedged | - Process or port active, but page count is 0<br>- DevTools page targets missing `webSocketDebuggerUrl`<br>- Session hung or window in uninitialized/blank state<br>- Previous job submission timed out or returned `submit_failed` | Job submission strictly prohibited; recovery required |
| **`FAILED`** | Bridge endpoint or process completely unreachable | - Antigravity process not running<br>- TCP port 9222 not listening<br>- DevTools endpoint connection refused or timed out<br>- `DevToolsActivePort` missing or unreadable | Job submission strictly blocked; startup required |

## 3. Recovery Procedures

### A. Recovery from `FAILED` State
1. Run `.\scripts\start-antigravity.ps1` to start Antigravity with `--remote-debugging-port=9222`.
2. Wait for port 9222 to enter the LISTENING state.
3. Execute `.\scripts\bridge-check.ps1` to confirm `STATUS: PASS (READY)`.
4. If startup fails, verify the executable path at `C:\Users\My Laptop\AppData\Local\Programs\antigravity\Antigravity.exe` and confirm no port conflicts exist on port 9222.

### B. Recovery from `STALE` State
1. Do not submit new jobs to a stale session.
2. Inspect the running Antigravity window to ensure the active workspace is loaded and not hung.
3. If the window is unresponsive or page targets remain at 0, close the Antigravity process and run `.\scripts\start-antigravity.ps1`.
4. Re-run `.\scripts\bridge-check.ps1` to ensure `STATUS: PASS (READY)` before submitting any work.

### C. Fresh-Codex-Session Recovery Steps
When a delegated bridge job fails (such as an offload exception, DevToolsActivePort missing error, or websocket drop):
1. **Halt Submissions**: Stop all queued delegations immediately.
2. **Inspect Bridge Status**: Run `.\scripts\bridge-check.ps1` to diagnose whether the issue is process absence, port listening failure, or target disconnection.
3. **Restart Bridge Service**: If port 9222 is not listening, launch or relaunch Antigravity via `.\scripts\start-antigravity.ps1`.
4. **Initiate Fresh Codex Session**: Close or reset the failing Codex session context to clear any poisoned websocket handles, stale task IDs, or broken client state.
5. **Verify Bridge Readiness**: In the fresh session, run `.\scripts\bridge-check.ps1` and verify that the output reports `PASS`.
6. **Resume Delegated Tasks**: Resubmit the task only after the fresh session has verified bridge `PASS`.

## 4. Operational Safety Constraints

- **Human Authority**: Human engineers retain ultimate control over task execution and Git mutations.
- **No Installation Tampering**: AI agents must never modify, delete, or rewrite files inside the Antigravity application directory (`AppData\Local\Programs\antigravity`).
- **No Forceful Process Termination**: Agents must not indiscriminately kill or restart running Antigravity processes unless explicitly instructed by the user or required for critical stale-session recovery.
- **Fail-Closed Safety**: Any ambiguity in bridge readiness must result in a fail-closed response, preventing corrupted task dispatch.

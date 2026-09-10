# Task Classification & Provider Routing Procedure

This document defines the deterministic routing decision procedure for incoming tasks, referencing the canonical contract and provider definitions in [`core/TASK_TEMPLATE.md`](TASK_TEMPLATE.md).

---

## 1. Canonical Contract Reference

Every task is evaluated across the six canonical fields defined in [`core/TASK_TEMPLATE.md`](TASK_TEMPLATE.md):
`INTENT`, `RISK`, `TARGET`, `ALLOWLIST`, `REVIEW`, `TEST`.

### Shorthand Expansion Rules
Incoming shorthand inputs (`TARGET`, `INTENT`, `ALLOWLIST`) expand to all six canonical fields using row defaults from [`prompts/shortcuts.md`](../prompts/shortcuts.md) for `RISK`, `REVIEW`, and `TEST`:
- **Read-Only Aliases**: Shorthand aliases for read-only modes (`/audit`, `/review`, `/debug`, `/release`) expand strictly to `ALLOWLIST: NONE`.
- **Request-Only Shortcuts**: `/test` creates a test request without writing tests; any test implementation is a separate Antigravity task with an explicit allowlist. `/fix` begins with Native Codex diagnosis and requires an explicit allowlist for its delegated implementation phase.
- **Explicit Overrides**: Explicit values provided in the request may refine table defaults, but never override provider boundaries, read-only/request-only restrictions, or the mandatory allowlist for delegated implementation.
- **Write Allowlist Enforcement**: Any write task missing an explicit, non-empty `ALLOWLIST` blocks execution (`STATUS: BLOCKED`).

---

## 2. Routing Decision Procedure

Evaluate tasks sequentially through five deterministic steps:

### Step 1: Evaluate INTENT & Select Provider
Identify the core objective and assign the appropriate provider (see [`core/TASK_TEMPLATE.md`](TASK_TEMPLATE.md) for full provider definitions):
- **ChatWeb**: Planning only. Route here for architectural decisions, trade-off analysis, ambiguity, cross-project choices, or unclear scope/risk/acceptance before writing code (no bridge required; no file modifications).
- **Native Codex**: Direct execution without bridge. Route here for read-only analysis, explanations, repository discovery, verification, and documentation/non-executable artifact writes only. It must not make behavior-changing repository modifications, even when they touch one file.
- **Antigravity**: Delegated desktop execution requiring bridge PASS (`STATUS: PASS (READY)`). Route here for all behavior-changing repository modifications, including single-file and multi-file edits, new files, source, tests, UI/runtime behavior, dependencies, configuration, database schemas/queries, auth/security, file uploads, or release work.
  * *Lane Isolation Rule*: Missing or uncertain bridge readiness blocks **only** the Antigravity lane; Native Codex and ChatWeb lanes continue unaffected.

### Step 2: Assess RISK
Classify the task risk level (`Low`, `Medium`, `High`, `Critical`):
- `Low`: Read-only queries, documentation, and non-executable artifact work. Behavior-changing work may still be Low risk, but it remains an Antigravity task.
- `Medium`: Standard business logic, bug fixes, multi-file functional changes.
- `High` / `Critical`: Authentication, security, database schemas/migrations, file storage/upload, or releases.

### Step 3: Enforce ALLOWLIST
- **Write Tasks**: Must supply an explicit, non-empty `ALLOWLIST` of permitted files or globs. Missing write `ALLOWLIST` blocks execution (`STATUS: BLOCKED`).
- **Read-Only Tasks**: Must explicitly declare `ALLOWLIST: NONE`.
- **Human Authority**: Staging, committing, pushing, tagging, deployments, and releases are exclusively human actions ([`core/GIT_POLICY.md`](GIT_POLICY.md)).

### Step 4: Assign Conditional REVIEW
- **`SELF`**: Permitted for `RISK: Low` read-only analysis, verification, or documentation/non-executable artifact writes with passing checks.
- **`PEER`**: Required for `RISK: Medium`, complex logic, or multi-file changes (`prompts/review.md` or `agents/reviewer.md`).
- **`HUMAN`**: Mandatory for `RISK: High`/`Critical`, architectural decisions, and all Git history mutations.

### Step 5: Determine Focused TEST
Select targeted tests for modified behavior per [`core/TEST_POLICY.md`](TEST_POLICY.md) (Tier 0 to Tier 4) without executing unnecessary monolithic suites.

---

## 3. Standard Output Contract

Every task completion response must conclude with the normalized output block:

```text
STATUS: <PASS | FAIL | BLOCKED | UNVERIFIED>
CHANGED: <List of modified file paths relative to project root verified via git status/diff, or NONE>
TEST: <Executed test/verification command(s) and results summary>
RISK: <Identified risks, caveats, or residual uncertainties>
NEXT: <Recommended next action for human engineer or subsequent phase>
```

Before reporting completion, execute the repository verification gate: `git status --short`, `git diff --name-only`, and `git diff --check` (priority: `actual workspace > git diff > worker artifacts`; if mismatch, report `STATUS: FAIL` or `STATUS: UNVERIFIED`).

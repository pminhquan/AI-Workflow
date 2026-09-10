# Workflow Shortcut Prompts (Compatibility Aliases)

Compact user-facing shortcuts that serve as thin compatibility aliases mapping directly into the canonical routing contract defined in [`core/TASK_TEMPLATE.md`](../core/TASK_TEMPLATE.md) and [`core/TASK_CLASSIFICATION.md`](../core/TASK_CLASSIFICATION.md).

---

## 1. Six-Field Expansion & Input Contract

Every shortcut maps into the six required canonical routing fields:
`INTENT`, `RISK`, `TARGET`, `ALLOWLIST`, `REVIEW`, `TEST`.

Shortcut shorthand input format:
```text
<shortcut>
TARGET: <project-path>
INTENT: <objective or description>
ALLOWLIST: <mandatory explicit file paths/globs for write tasks, or NONE>
```
*(Legacy `PROJECT:` and `TASK:` parameters remain supported as compatibility aliases for `TARGET:` and `INTENT:`).*

### Deterministic Expansion Rules
When a shortcut is invoked with shorthand inputs (`TARGET`, `INTENT`, `ALLOWLIST`), it automatically expands to all six canonical contract fields using the shortcut directory table row defaults below:
1. **Field Derivation**: `RISK`, `REVIEW`, and `TEST` default to the row values in the Shortcut Directory table.
2. **Read-Only Aliases**: Shortcuts marked read-only (`/audit`, `/review`, `/debug`, `/release`) strictly expand to `ALLOWLIST: NONE`.
3. **Request-Only Shortcuts**: `/test` creates a focused test request with `ALLOWLIST: NONE`; any test implementation is delegated to Antigravity with an explicit allowlist.
4. **Two-Phase Fix**: `/fix` uses Native Codex for read-only diagnosis, then delegates any behavior-changing implementation to Antigravity with an explicit allowlist.
5. **Explicit Override**: Explicit values may refine the row defaults, but never override provider boundaries, read-only/request-only restrictions, or the mandatory allowlist for delegated implementation.
6. **Missing Allowlist Blocking**: Any behavior-changing write task without an explicit, non-empty `ALLOWLIST` blocks execution (`STATUS: BLOCKED`).

---

## 2. Concrete `/fix` Routing Boundary

For a clear defect, the `/fix` shortcut uses this two-phase flow:
1. **Native Codex** diagnoses the defect read-only, using existing checks where available. No behavior-changing edit is permitted.
2. **Antigravity** implements every behavior-changing fix, including a one-file fix or new test, after bridge readiness verification (`STATUS: PASS (READY)`) and explicit allowlist confirmation.

When scope, root cause, risk, acceptance criteria, architecture, or cross-project trade-offs are unclear, ChatWeb planning occurs before these two phases.

---

## 3. Shortcut Directory & Provider Routing

| Shortcut | Target Intent | Primary Provider | Default Risk | Conditional Review | Default Test Tier | Allowlist Default |
|---|---|---|---|---|---|---|
| `/fix` | Diagnose defect, then delegate implementation | Native Codex (diagnosis) → Antigravity (implementation) | `Medium` | `PEER` | `Tier 2` | `NONE` for diagnosis; explicit allowlist for implementation |
| `/feature` | Feature implementation | Antigravity | `Medium` | `PEER` | `Tier 2` | Explicit write allowlist required |
| `/debug` | Diagnosis only; no implementation | Native Codex | `Medium` | `PEER` | `Tier 2` | `NONE` |
| `/audit` | Read-only inspection and evaluation | Native Codex | `Low` | `SELF` | `Tier 0` | `NONE` |
| `/review` | Independent diff assessment | Native Codex | `Low` | `SELF` | `Tier 0` | `NONE` |
| `/test` | Create a focused test request; do not write tests | Native Codex (request) → Antigravity (implementation) | `Low` | `PEER` | `Tier 2` | `NONE` for request; explicit allowlist for implementation |
| `/release` | Release gate inspection (`RELEASE_CHECK`) | Native Codex | `High` | `HUMAN` | `Tier 4` | `NONE` |
| `/ui` | Frontend, UI layout, and styling | Antigravity | `Low` | `SELF` | `Tier 1` | Explicit write allowlist required |
| `/db` | Database schema and queries | Antigravity | `High` | `HUMAN` | `Tier 3` | Explicit write allowlist required |
| `/security` | Authentication and security hardening | Antigravity | `High` | `HUMAN` | `Tier 3` | Explicit write allowlist required |

---

## 4. Core Operating Invariants

1. **Provider Routing & Bridge Rules**:
   - Native Codex handles read-only analysis, explanations, discovery, verification, and documentation/non-executable artifact writes without the bridge.
   - ChatWeb handles architecture and trade-off planning without file changes.
   - Antigravity handles all behavior-changing repository modifications, including single-file changes, tests, UI/runtime, and implementations; bridge readiness (`STATUS: PASS (READY)`) is required only for this lane.
2. **Mandatory Write Allowlists**: Every write task requires an explicit non-empty `ALLOWLIST`. Modifying files outside the allowlist is prohibited.
3. **Human Git Boundary**: Human approval is exclusive for `git add`, `git commit`, `git push`, `git tag`, deployments, and releases ([`core/GIT_POLICY.md`](../core/GIT_POLICY.md)).
4. **Normalized Output**: All completions conclude with standard block (`STATUS: <PASS | FAIL | BLOCKED | UNVERIFIED>`, `CHANGED`, `TEST`, `RISK`, `NEXT`) and mandatory repository-state checks (`git status --short`, `git diff --name-only`, `git diff --check`).

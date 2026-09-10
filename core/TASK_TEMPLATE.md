# Canonical Routing Contract

This document defines the canonical routing contract for task execution across AI providers.

---

## 1. Canonical Routing Contract

Every task must provide exactly these six required fields; do not omit or infer them:

```text
INTENT: <goal, action, defect, or objective to solve>
RISK: <Low | Medium | High | Critical>
TARGET: <project path, repository, or component>
ALLOWLIST: <explicit comma-separated file paths or globs; mandatory for write tasks; NONE for read-only>
REVIEW: <conditional review rule: SELF | PEER | HUMAN>
TEST: <focused verification command, tier (Tier 0-4), or evidence>
```

### Required Fields Definition

1. **INTENT**: Objective and scope of work (e.g., diagnosis, verification, documentation artifact, bug fix, feature, or planning).
2. **RISK**: Risk classification (`Low`, `Medium`, `High`, `Critical`) and brief rationale.
3. **TARGET**: Target project workspace path, repository, or component.
4. **ALLOWLIST**: Explicit, mandatory file paths or globs permitted for creation/modification. Must be `NONE` for read-only tasks. Write tasks without an explicit allowlist are blocked.
5. **REVIEW**: Conditional review requirement:
   - `SELF`: Permitted for `Low` risk read-only analysis, verification, or documentation/non-executable artifact writes with passing checks.
   - `PEER`: Required for `Medium` risk, complex logic, or multi-file changes (`reviewer.md`).
   - `HUMAN`: Mandatory for `High`/`Critical` risk, architecture changes, database/auth/security, release gates, and Git mutations.
6. **TEST**: Focused verification rule or command matching the required tier (`core/TEST_POLICY.md`). Target only modified behavior and boundaries.

---

## 2. Provider Routing Architecture

Tasks route deterministically to one of three providers:

| Provider | Permitted Scope | Bridge Requirement |
|---|---|---|
| **Native Codex** | Read-only analysis, explanations, repository discovery, verification, and documentation/non-executable artifact writes only. It must not make behavior-changing repository modifications, including source, test, UI, runtime, dependency, schema, security, upload, or behavior-affecting configuration changes. | **Not required**. Operates directly in local workspace. |
| **ChatWeb** | Planning only for ambiguity, architecture decisions, trade-off analysis, cross-project choices, or unclear acceptance criteria (no file modifications). | **Not required**. Interactive planning only; no disk writes. |
| **Antigravity** | All behavior-changing repository modifications, including single-file and multi-file edits, new files, source, tests, UI/runtime behavior, dependencies, configuration, database/auth/security/upload, and release implementation after bridge readiness. | **Required**. Must verify bridge readiness (`STATUS: PASS (READY)`). |

> [!IMPORTANT]
> The bridge is required **only** for Antigravity work. Missing or uncertain Antigravity readiness blocks **only** that lane; Native Codex and ChatWeb lanes continue unaffected.

**Routing boundary:** If a task changes repository behavior, route the implementation to Antigravity even when the change touches only one file. Native Codex may prepare the analysis or request and may write only documentation/non-executable artifacts.

---

## 3. Governance Boundaries

- **Mandatory Allowlist**: All write tasks require an explicit, non-empty `ALLOWLIST`. AI agents must never modify files outside the allowlist.
- **Human Authority**: Human approval is exclusive for `git add`, `git commit`, `git push`, `git tag`, branch operations, deployments, releases, and other Git history mutations.
- **Mandatory Final Repository Gate**: Run `git status --short`, `git diff --name-only`, and `git diff --check` before completion. Actual workspace state is authoritative: `actual workspace > git diff > worker artifacts`. If worker artifacts and repo state differ, return `STATUS: FAIL` (or `STATUS: UNVERIFIED`).

---

## 4. Standard Output Contract

Every task completion response must conclude with:

```text
STATUS: <PASS | FAIL | BLOCKED | UNVERIFIED>
CHANGED: <List of modified file paths relative to project root verified via git status/diff, or NONE>
TEST: <Executed test and gate command(s) with result summary>
RISK: <Identified risks, caveats, or residual uncertainties>
NEXT: <Recommended next action for human engineer or subsequent phase>
```

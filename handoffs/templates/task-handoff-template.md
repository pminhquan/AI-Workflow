# Task Handoff Contract

Markdown-only handoff record shared by User, ChatWeb, Native Codex, and Antigravity.

## META
- **ID**: `<stable-task-id>`
- **STATE**: `CREATED`
- **CREATED_AT**: `<ISO-8601 timestamp>`
- **UPDATED_AT**: `<ISO-8601 timestamp>`
- **SOURCE**: `User | ChatWeb | Native Codex | Antigravity`

## INTENT
<!-- State the objective and scope in one or two sentences. -->

`<objective>`

## RISK
<!-- Use Low, Medium, High, or Critical and state the reason. -->

`<risk level and rationale>`

## TARGET
<!-- Identify the workspace, repository, component, or document scope. -->

`<target>`

## ALLOWLIST
<!-- List the only files or paths permitted to change. Use NONE for read-only work. -->

`<explicit paths or globs>`

## EXECUTOR
<!-- Select exactly one responsible provider. No autonomous reassignment. -->

`User | ChatWeb | Native Codex | Antigravity`

## ACCEPTANCE CRITERIA
- [ ] `<observable criterion>`

## TEST
- **Check**: `<focused command or verification>`
- **Expected**: `<pass condition>`
- **Result**: `UNVERIFIED`

## EVIDENCE
- **Artifact Directory**: `<explicit evidence directory or artifact location>`
- **Changed files**: `<verified paths or NONE>`
- **Result**: `<test output, review note, or artifact reference>`
- **Risks / limitations**: `<remaining risk or NONE>`

## Lifecycle

`META.STATE` must contain exactly one of:

`CREATED` · `SUBMITTED` · `RUNNING` · `ARTIFACT_READY` · `VERIFIED` · `CLOSED`

Normal progression:

`CREATED -> SUBMITTED -> RUNNING -> ARTIFACT_READY -> VERIFIED -> CLOSED`

Validation outcome (`PASS`, `FAIL`, `BLOCKED`, `UNVERIFIED`) is recorded under `TEST` and `EVIDENCE`, kept strictly separate from lifecycle state.

## Provider boundaries

- **User** owns intent, approvals, architecture decisions, and Git lifecycle actions.
- **ChatWeb** may clarify scope and plan; it does not modify files.
- **Native Codex** may inspect, verify, and write non-executable documentation artifacts.
- **Antigravity** performs approved repository implementation within `ALLOWLIST`.

## Non-goals

This contract is only a Markdown record. It adds no database, dashboard, task registry, agent framework, autonomous orchestration, scheduler, or new service.

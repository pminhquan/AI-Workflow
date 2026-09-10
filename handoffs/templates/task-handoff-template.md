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
- **Changed files**: `<verified paths or NONE>`
- **Result**: `<test output, review note, or artifact reference>`
- **Risks / limitations**: `<remaining risk or NONE>`

## Lifecycle

`META.STATE` must contain exactly one of:

`CREATED` · `READY` · `EXECUTING` · `VERIFYING` · `COMPLETED` · `FAILED`

Normal progression:

`CREATED -> READY -> EXECUTING -> VERIFYING -> COMPLETED`

Any active state may become `FAILED` when execution is blocked or verification fails. A failed handoff is terminal until a new handoff is created.

## Provider boundaries

- **User** owns intent, approvals, architecture decisions, and Git lifecycle actions.
- **ChatWeb** may clarify scope and plan; it does not modify files.
- **Native Codex** may inspect, verify, and write non-executable documentation artifacts.
- **Antigravity** performs approved repository implementation within `ALLOWLIST`.

## Non-goals

This contract is only a Markdown record. It adds no database, dashboard, task registry, agent framework, autonomous orchestration, scheduler, or new service.

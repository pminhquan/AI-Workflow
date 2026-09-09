# AI Development Workflow Framework

A reusable, project-agnostic AI development workflow framework designed to establish structured, safe pair programming and task delegation between human engineers and AI agents.

## Overview

In this framework:
- **Human Authority**: The human developer owns all architecture decisions, data integrity, and Git operations (commit, push, tag, release, deploy).
- **AI as Assistant**: The AI operates strictly as an assistant under bounded context, clear task definitions, and explicit verification gates.
- **Principle of Least Change**: Inspect before editing; make only the minimal necessary modifications to achieve the goal without extraneous refactoring or speculative features.
- **Safety by Default**: Automatic Git mutation commands (`git add`, `git commit`, `git push`, `git tag`, `git reset`, `git restore`, `git clean`) and deployment actions are strictly prohibited for AI agents.

## Directory Structure

```
.
├── agents/                  # Role-specific responsibility definitions
│   ├── architect.md         # Requirements analysis, architecture definition, risk identification
│   ├── developer.md         # Implementation, minimal modification, verification evidence
│   ├── reviewer.md          # Diff inspection, regression finding, read-only review
│   ├── tester.md            # Test tier selection, evidence verification, QA rigor
│   └── security.md          # Auth, secrets management, permissions, data safety
├── core/
│   ├── AGENT_RULES.md               # Global governing rules, operational constraints, and boundaries
│   ├── TASK_TEMPLATE.md             # Standardized contract for task specification and handover
│   ├── QUICK_TASK_TEMPLATE.md       # Compact daily-use task template with automatic derivations
│   ├── TASK_CLASSIFICATION.md       # Deterministic task categories, inference rules, and escalation policy
│   ├── TEST_POLICY.md               # Tiered testing model (Tier 0 to Tier 4) and verification gates
│   ├── GIT_POLICY.md                # Explicit Git rules, human-only operations, and branch lifecycle
│   └── PROJECT_CONTEXT_TEMPLATE.md  # Template for project-specific stack, architecture, and constraints
├── prompts/
│   ├── audit.md             # Prompt template for AUDIT mode (read-only inspection & analysis)
│   ├── implement.md         # Prompt template for IMPLEMENT mode (scoped code modifications)
│   ├── review.md            # Prompt template for REVIEW mode (code & diff review against criteria)
│   ├── debug.md             # Prompt template for DEBUG mode (root-cause diagnosis & surgical fix)
│   ├── release.md           # Prompt template for RELEASE_CHECK mode (pre-release validation)
│   └── shortcuts.md         # Compact workflow shortcuts (/fix, /feature, /ui, etc.)
├── scripts/
│   ├── git-check.ps1        # Read-only Git status, branch, and working-tree health check
│   ├── diff-check.ps1       # Read-only diff inspection and modification boundary check
│   ├── release-check.ps1    # Read-only pre-release readiness and gate verification check
│   └── load-context.ps1     # Read-only project context and suggested skill loader
├── skills/                  # Domain-specific technical skill guidelines
│   ├── java-web/skill.md    # Java web services, REST endpoints, and middleware practices
│   ├── python/skill.md      # Python modules, packaging, typing, and async practices
│   ├── database/skill.md    # Schema migrations, query design, and data integrity practices
│   ├── frontend/skill.md    # UI components, responsive layout, styling, and accessibility
│   └── release/skill.md     # Pre-release readiness, artifact checks, and gate audits
└── README.md                # Framework documentation and usage guide
```

## Agent Modes

| Mode | Purpose | Permitted Actions |
|---|---|---|
| `AUDIT` | Read-only analysis, architecture inspection, threat/risk evaluation | Read codebase, summarize findings, recommend changes |
| `IMPLEMENT` | Code generation and feature implementation within allowlist | Edit files within allowlist, run validation tests |
| `REVIEW` | Independent review of changes against task criteria and diff scope | Inspect diffs, verify constraints, report issues |
| `DEBUG` | Root cause analysis and minimal corrective fix | Trace failure, reproduce with test, apply minimal fix |
| `RELEASE_CHECK` | Pre-release sanity check and gate compliance validation | Run read-only checks, verify readiness tiers |

## Quick Task Format (Daily Use)

For routine daily workflow tasks, use `core/QUICK_TASK_TEMPLATE.md` to minimize input overhead. The human provides only two required fields (with optional overrides); the workflow deterministically classifies the task and derives remaining execution parameters:

```text
PROJECT: <path>
TASK: <goal>
RISK: [Optional: Low | Medium | High | Critical]
ALLOWLIST: [Optional: permitted file paths or glob patterns]
CONSTRAINTS: [Optional: specific boundaries or non-goals]
```

- **Deterministic Classification (`core/TASK_CLASSIFICATION.md`)**: Automatically maps the task into one of 10 categories (`UI`, `BACKEND_LOGIC`, `DATABASE`, `AUTH_SECURITY`, `UPLOAD_FILE`, `TESTING`, `DEBUG`, `DOCUMENTATION`, `RELEASE`, `MIXED`) via normalized keyword and path signatures.
- **Automated Parameter Derivations**: Infers default `MODE`, default `RISK`, recommended agents (`agents/`), recommended skills (`skills/`), and default test tier (`core/TEST_POLICY.md`) as provisional context. For `MIXED`, recommended skills resolve to the union of matched category skills (`frontend`, `java-web`, `python`, `database`, `release`).
- **Precedence & Escalation**: Explicit inputs always override inferred values. Cross-domain overlaps resolve to `MIXED`. Ambiguous, contradictory, unknown-scope, or High/Critical-risk tasks (including high-risk categories `DATABASE`, `AUTH_SECURITY`, `UPLOAD_FILE`, `RELEASE`, `MIXED`) produce an explicit `ESCALATE` outcome and halt for human clarification/confirmation (never guessing or defaulting to MODE AUDIT). When classification returns `ESCALATE`, the standard response uses `STATUS: BLOCKED` and `NEXT` requests human clarification or confirmation.
- **Safety Invariants Preserved**: Classification NEVER grants permission for `git add`, `git commit`, `git push`, `git tag`, deploy actions, or destructive database operations (`DROP TABLE`, `TRUNCATE`, destructive migrations). Strictly preserves the human Git boundary and the mandatory repository verification gate (`git status --short`, `git diff --name-only`, `git diff --check`).

## Daily Usage

For rapid daily handoff, the framework provides 10 compact workflow shortcuts documented in `prompts/shortcuts.md`: `/fix`, `/feature`, `/debug`, `/audit`, `/review`, `/test`, `/release`, `/ui`, `/db`, `/security`.

Shortcuts use minimal input (normal shortcuts use `PROJECT` plus `TASK`; `/debug` accepts `ISSUE:`; `/audit` accepts `SCOPE:`; `/release` may be project-only for a project-level release check). Execution parameters (`MODE`, `RISK`, `AGENTS`, `SKILLS`, `GATES`) are derived through canonical policies (`core/TASK_CLASSIFICATION.md`, `core/TEST_POLICY.md`, `core/AGENT_RULES.md`, `core/GIT_POLICY.md`, and optional project `.ai/CONTEXT.md` when present). For `/feature`, `/audit`, and `/review`, category and downstream parameters are deferred to `core/TASK_CLASSIFICATION.md`. High-risk escalation depends on the classifier's resulting high-risk category or explicit `RISK: High`/`Critical`, not solely on shortcut names.

### Examples

```text
/fix PROJECT: D:\PROJECT\Example TASK: Fix avatar upload
/ui PROJECT: D:\PROJECT\Example TASK: Improve navbar spacing
/audit PROJECT: D:\PROJECT\Example SCOPE: authentication
/release PROJECT: D:\PROJECT\Example
```

- **Safety Invariants**: Shortcuts never grant permission for `git add`, `commit`, `push`, `tag`, deployment, destructive DB operations, or secret access. Ambiguous or high-risk tasks mandate `ESCALATE` halting (`STATUS: BLOCKED`).
- **Repository Verification Gate**: The mandatory repository verification gate (`git status --short`, `git diff --name-only`, `git diff --check`) must execute before reporting completion.

## Standard Output Format

All AI responses must conclude with or conform to the standard output format:
```text
STATUS: <COMPLETED | IN_PROGRESS | WARNING | BLOCKED | FAILED>
CHANGED: <Comma-separated list of modified files, or NONE>
TEST: <Executed test commands and summary of results (e.g., PASS: 4, FAIL: 0)>
RISK: <Identified risks, regressions, or assumptions>
NEXT: <Recommended next action for human or next task phase>
```

## Basic Usage

1. **Define & Load Project Context (Optional)**: If desired, copy `core/PROJECT_CONTEXT_TEMPLATE.md` to `.ai/CONTEXT.md` in the target project to document stack details (repository context is optional; no AI-specific project assumptions are made). Run the context loader to inspect context and suggested skills:
   ```powershell
   ./scripts/load-context.ps1 -ProjectPath "/path/to/project"
   ```
2. **Define the Task**: Choose either the compact daily-use format in `core/QUICK_TASK_TEMPLATE.md` (minimal quick input with deterministic inference and escalation via `core/TASK_CLASSIFICATION.md`) or the full contract in `core/TASK_TEMPLATE.md`.
3. **Select Mode Prompt**: Use the corresponding prompt in `prompts/` (e.g., `prompts/implement.md`) along with the filled task template.
4. **Inspect First**: The AI reads relevant files, verifies existing behavior, and confirms understandability before touching code.
5. **Execute & Test**: Make minimal targeted changes strictly inside the `ALLOWLIST`. Execute the required test tier from `core/TEST_POLICY.md`.
6. **Read-Only Verification**: Run the read-only PowerShell scripts in `scripts/` (`git-check.ps1`, `diff-check.ps1`, `release-check.ps1`) to verify clean boundaries.
7. **Human Review & Git Mutation**: The human engineer reviews the final diff and executes Git commands manually.

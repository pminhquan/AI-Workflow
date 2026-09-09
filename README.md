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
│   ├── TEST_POLICY.md               # Tiered testing model (Tier 0 to Tier 4) and verification gates
│   ├── GIT_POLICY.md                # Explicit Git rules, human-only operations, and branch lifecycle
│   └── PROJECT_CONTEXT_TEMPLATE.md  # Template for project-specific stack, architecture, and constraints
├── prompts/
│   ├── audit.md             # Prompt template for AUDIT mode (read-only inspection & analysis)
│   ├── implement.md         # Prompt template for IMPLEMENT mode (scoped code modifications)
│   ├── review.md            # Prompt template for REVIEW mode (code & diff review against criteria)
│   ├── debug.md             # Prompt template for DEBUG mode (root-cause diagnosis & surgical fix)
│   └── release.md           # Prompt template for RELEASE_CHECK mode (pre-release validation)
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

For daily workflow tasks, use `core/QUICK_TASK_TEMPLATE.md` to minimize input overhead. The human provides only four required fields (and optional allowlist/constraints); the workflow automatically derives remaining execution parameters:

```text
MODE: [AUDIT | IMPLEMENT | REVIEW | DEBUG | RELEASE_CHECK]
PROJECT: [Project Name or Path]
GOAL: [Clear statement of the objective]
RISK: [Low | Medium | High | Critical] - [Brief risk rationale]
ALLOWLIST: [Optional: permitted file paths or glob patterns]
CONSTRAINTS: [Optional: specific constraints or boundaries]
```

- **Automated Derivations**: The workflow automatically derives agents (`agents/`), skills (`skills/`), test tier (`core/TEST_POLICY.md`), verification rules, and Git policy (`core/GIT_POLICY.md`).
- **Safety Invariants Preserved**: Strictly preserves no auto commit, no auto push, the human Git boundary, and the mandatory repository verification gate (`git status --short`, `git diff --name-only`, `git diff --check`).

## Standard Output Format

All AI responses must conclude with or conform to the standard output format:
```text
STATUS: <COMPLETED | IN_PROGRESS | BLOCKED | FAILED>
CHANGED: <Comma-separated list of modified files, or NONE>
TEST: <Executed test commands and summary of results (e.g., PASS: 4, FAIL: 0)>
RISK: <Identified risks, regressions, or assumptions>
NEXT: <Recommended next action for human or next task phase>
```

## Basic Usage

1. **Define & Load Project Context**: Copy `core/PROJECT_CONTEXT_TEMPLATE.md` to `.ai/CONTEXT.md` in the target project. Run the context loader to inspect context and suggested skills:
   ```powershell
   ./scripts/load-context.ps1 -ProjectPath "/path/to/project"
   ```
2. **Define the Task**: Choose either the compact daily-use format in `core/QUICK_TASK_TEMPLATE.md` (requires only `MODE`, `PROJECT`, `GOAL`, `RISK` with automatic derivations) or the full contract in `core/TASK_TEMPLATE.md`.
3. **Select Mode Prompt**: Use the corresponding prompt in `prompts/` (e.g., `prompts/implement.md`) along with the filled task template.
4. **Inspect First**: The AI reads relevant files, verifies existing behavior, and confirms understandability before touching code.
5. **Execute & Test**: Make minimal targeted changes strictly inside the `ALLOWLIST`. Execute the required test tier from `core/TEST_POLICY.md`.
6. **Read-Only Verification**: Run the read-only PowerShell scripts in `scripts/` (`git-check.ps1`, `diff-check.ps1`, `release-check.ps1`) to verify clean boundaries.
7. **Human Review & Git Mutation**: The human engineer reviews the final diff and executes Git commands manually.

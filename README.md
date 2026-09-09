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
│   ├── AGENT_RULES.md       # Global governing rules, operational constraints, and boundaries
│   ├── TASK_TEMPLATE.md     # Standardized contract for task specification and handover
│   ├── TEST_POLICY.md       # Tiered testing model (Tier 0 to Tier 4) and verification gates
│   └── GIT_POLICY.md        # Explicit Git rules, human-only operations, and branch lifecycle
├── prompts/
│   ├── audit.md             # Prompt template for AUDIT mode (read-only inspection & analysis)
│   ├── implement.md         # Prompt template for IMPLEMENT mode (scoped code modifications)
│   ├── review.md            # Prompt template for REVIEW mode (code & diff review against criteria)
│   ├── debug.md             # Prompt template for DEBUG mode (root-cause diagnosis & surgical fix)
│   └── release.md           # Prompt template for RELEASE_CHECK mode (pre-release validation)
├── scripts/
│   ├── git-check.ps1        # Read-only Git status, branch, and working-tree health check
│   ├── diff-check.ps1       # Read-only diff inspection and modification boundary check
│   └── release-check.ps1    # Read-only pre-release readiness and gate verification check
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

1. **Define the Task**: Copy `core/TASK_TEMPLATE.md` to define the task. Fill in `MODE`, `PROJECT`, `RISK`, `BASE_SHA`, `GOAL`, `ALLOWLIST`, `FORBIDDEN_ACTIONS`, `ACCEPTANCE_CRITERIA`, and `GATES`.
2. **Select Mode Prompt**: Use the corresponding prompt in `prompts/` (e.g., `prompts/implement.md`) along with the filled task template.
3. **Inspect First**: The AI reads relevant files, verifies existing behavior, and confirms understandability before touching code.
4. **Execute & Test**: Make minimal targeted changes strictly inside the `ALLOWLIST`. Execute the required test tier from `core/TEST_POLICY.md`.
5. **Read-Only Verification**: Run the read-only PowerShell scripts in `scripts/` (`git-check.ps1`, `diff-check.ps1`, `release-check.ps1`) to verify clean boundaries.
6. **Human Review & Git Mutation**: The human engineer reviews the final diff and executes Git commands manually.

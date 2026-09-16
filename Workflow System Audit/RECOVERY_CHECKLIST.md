# AI Workflow Recovery Checklist

Version:
AI Workflow v1.0 Stable


## Restore order

### 1. Install applications

Required:

- Git
- Codex Desktop
- Antigravity Desktop


### 2. Restore repositories

AI-Workflow:

D:\AI-Workflow

Memory:

D:\AI\codex-anti


### 3. Restore Codex configuration

Restore:

- AGENTS.md
- config.toml
- config.json
- rules/


### 4. Restore Antigravity

Restore:

- .mcp.json
- scripts/
- skills/
- .codex-plugin/


### 5. Verify MCP

Expected servers:

- antigravity_local
- antigravity_devtools


### 6. Validation

Run:

workflow-check.ps1

bridge-check.ps1

bridge-golden-path-check.ps1


Expected:

PASS


## Recovery notes

Runtime artifacts:

.antigravity-bridge/jobs/

are not restored.

Only validated evidence jobs should be recreated if needed.
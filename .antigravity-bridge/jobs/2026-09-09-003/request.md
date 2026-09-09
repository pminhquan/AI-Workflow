# Antigravity Bridge Job 2026-09-09-003

Goal: Implement WORKFLOW-V2-001 inside D:\AI-Workflow only.

The task is MODE=IMPLEMENT: upgrade the existing global AI workflow into a reusable multi-project framework. Do not inspect, read, write, or modify any external project, repository, or user document. Do not use git add, git commit, git push, deployment, reset, restore, clean, checkout, merge, rebase, or stash.

Inspect the existing D:\AI-Workflow framework first and preserve its current content. Create exactly these new Markdown files:
- agents\architect.md
- agents\developer.md
- agents\reviewer.md
- agents\tester.md
- agents\security.md
- skills\java-web\skill.md
- skills\python\skill.md
- skills\database\skill.md
- skills\frontend\skill.md
- skills\release\skill.md

You may update README.md only minimally to index the new agents/ and skills/ directories, if the current README does not already describe them. Do not modify core/, prompts/, scripts/, or any other existing file.

AGENTS requirements:
- Define role responsibilities only.
- Keep every agent file project-agnostic.
- Do not put Java-specific assumptions in any agent file.
- Architect responsibilities must include analyzing requirements, defining architecture, and identifying risks.
- Developer responsibilities must include implementing changes, minimal modification, and providing evidence.
- Reviewer responsibilities must include inspecting diffs, finding regressions, and no modification.
- Tester responsibilities must include choosing the test tier and verifying evidence.
- Security responsibilities must cover auth, secrets, permissions, and data safety.

SKILLS requirements:
Each skill.md must contain clearly labeled sections for:
1. When to use
2. Required context
3. Common risks
4. Testing expectations
5. Forbidden actions

Make each skill reusable and domain-appropriate for its named area (java-web, python, database, frontend, release), without project names, concrete credentials, personal paths, or assumed project architecture. Keep role responsibilities separate from domain skills. Preserve the global human-owns-architecture/Git rule and no automatic Git mutation/deployment rule where relevant.

Use concise Markdown with valid heading structure. Do not add dependencies, scripts, templates, generated code, or speculative abstractions.
Workspace: D:\AI-Workflow
Mode: patch

Routing decision: DIRECT
Workflow mode: DIRECT
Routing reason: Documentation task handled directly by Codex.
Executor: antigravity
Submission status: queued
Execution status: queued
Result artifact: result.md

Patch mode: make a narrow safe edit, run relevant verification, and produce a diff.

Next step: Create and validate only the requested agents/ and skills/ Markdown files, plus an optional minimal README index update. Verify all requested paths exist, every skill has the five required sections, every agent stays project-agnostic, no agent contains Java-specific assumptions, and no external path was modified. Return compact status.json, result.md, changed-files.txt, diff.patch, and test-output-summary.md with an explicit outside-scope answer.

JobId: 2026-09-09-003
JobFolder: D:\AI-Workflow\.antigravity-bridge\jobs\2026-09-09-003
Required artifacts:
- status.json: state, currentStep, startedAt, updatedAt, blocker if any.
- result.md: max 10 bullets with outcome, risk, and next step.
- changed-files.txt: one changed path per line, or NONE.
- diff.patch: compact patch/diff if files changed, or empty.
- test-output-summary.md: commands run and pass/fail summary only.

Do not paste full files, full logs, screenshots, or full chat transcripts.

Codex will read only result.md, changed-files.txt, diff.patch, test-output-summary.md, and status.json.

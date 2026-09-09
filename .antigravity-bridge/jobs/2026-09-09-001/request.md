# Antigravity Bridge Job 2026-09-09-001

Goal: Create a reusable, project-agnostic global AI development workflow framework inside D:\AI-Workflow only.

The user requires Codex to orchestrate and Codex-anti to do all file creation. Work only inside D:\AI-Workflow. Do not inspect, read, write, or modify any other repository, source-code project, or user document. Do not run or perform git add, commit, push, tag, deploy, reset, restore, clean, or other destructive Git operations.

Inspect the target directory first, preserve any existing user work, then create the requested files:
- core\AGENT_RULES.md
- core\TASK_TEMPLATE.md
- core\TEST_POLICY.md
- core\GIT_POLICY.md
- prompts\audit.md
- prompts\implement.md
- prompts\review.md
- prompts\debug.md
- prompts\release.md
- scripts\git-check.ps1
- scripts\diff-check.ps1
- scripts\release-check.ps1
- README.md

Requirements for the content:
1. Global rules: AI is an assistant; the human owns architecture and Git decisions; no automatic add/commit/push/tag/deploy; inspect before editing; minimum necessary changes.
2. Every task template must contain exactly the requested concepts/fields: MODE, PROJECT, RISK, BASE_SHA, GOAL, ALLOWLIST, FORBIDDEN_ACTIONS, ACCEPTANCE_CRITERIA, GATES, REQUIRED_OUTPUT.
3. Agent modes: AUDIT, IMPLEMENT, REVIEW, DEBUG, RELEASE_CHECK.
4. Standard output fields: STATUS:, CHANGED:, TEST:, RISK:, NEXT:.
5. Test policy tiers: Tier 0 docs/static, Tier 1 UI, Tier 2 logic, Tier 3 security/database/risky, Tier 4 release.
6. Keep all content project-agnostic. Do not include Java rules, Python rules, database credentials, personal paths, or specific project architecture.
7. Scripts must be read-only checks and must not mutate Git or deploy anything. Use portable, conservative PowerShell; fail clearly when checks cannot be satisfied. Keep implementation minimal and reusable.
8. README must explain the layout and basic usage without project-specific assumptions.

Validate the created files in this workspace, including PowerShell parse/syntax checks where practical, required headings/fields, and a scan that no requested file contains prohibited project-specific content or automatic Git mutation commands. Return compact artifacts only.
Workspace: D:\AI-Workflow
Mode: deep

Routing decision: DIRECT
Workflow mode: DIRECT
Routing reason: Documentation task handled directly by Codex.
Executor: antigravity
Submission status: queued
Execution status: queued
Result artifact: result.md

Deep mode: inspect related modules and prior patterns, run the strongest practical tests, and include risk notes.

Next step: Create and validate the files now. Record the exact changed-file list and concise test evidence. Explicitly state whether anything outside D:\AI-Workflow was modified; the required answer is no. Write all durable job artifacts under the workspace job directory only.

JobId: 2026-09-09-001
JobFolder: D:\AI-Workflow\.antigravity-bridge\jobs\2026-09-09-001
Required artifacts:
- status.json: state, currentStep, startedAt, updatedAt, blocker if any.
- result.md: max 10 bullets with outcome, risk, and next step.
- changed-files.txt: one changed path per line, or NONE.
- diff.patch: compact patch/diff if files changed, or empty.
- test-output-summary.md: commands run and pass/fail summary only.

Do not paste full files, full logs, screenshots, or full chat transcripts.

Codex will read only result.md, changed-files.txt, diff.patch, test-output-summary.md, and status.json.

AI Workflow System Specification: Current-State Architecture & Recovery Guide

Document Status: Official Architecture & Recovery Specification
Workspace: D:\AI-Workflow\Workflow System Audit
Authoritative Repositories: D:\AI-Workflow, D:\AI\codex-anti
Scope: Documentation of Implemented Current State, Governance
Boundaries, Lifecycle, and Recovery

Evidence scope and source notation

Inspected on 2026-09-16. Unqualified source paths refer to
D:\AI-Workflow; projects/... memory references refer to
D:\AI\codex-anti. The inspected external bridge source is
C:\Users\My Laptop\plugins\antigravity-2. These references are
snapshot evidence and may drift after changes.

Policy requirements are distinguished below from actual producer
behavior. The diagram is a logical responsibility flow, not an
automatically running pipeline. No runtime suite, readiness probe, or
clean-machine recovery was executed for this documentation task. Exact
installed-version compatibility and recovery success remain unknown.
## 1. System Purpose

1.1 Why This Workflow Exists

The AI Workflow framework coordinates collaborative software engineering
across human engineers and multiple AI agent providers (Codex Desktop,
ChatWeb, and Antigravity Desktop). Modern language models excel at code
reasoning and synthesis, but when deployed without deterministic
boundaries, they risk prompt bloat, hallucinated dependencies, silent
regression of untouched subsystems, and unauthorized source mutations.
This workflow establishes an auditable, deterministic, file-based
governance mechanism where AI agents operate within bounded sandboxes
while preserving human engineering authority.

1.2 Problems It Solves

Unbounded Source Code Mutations: Without explicit boundaries, AI
agents frequently perform unsolicited refactoring, touch unintended
files, or mutate version control histories
(core/AGENT_RULES.md:27-33).

Context Window Exhaustion and Prompt Bloat: Monolithic context
dumping wastes token budgets, degrades attention quality, and
introduces noise. The system enforces bounded, progressive context
loading (scripts/context-loader.ps1:28-29).

Ambiguous Provider Execution: Undifferentiated model routing
leads to mismatched execution lanes (e.g., executing shell scripts
in browser tools, or offloading read-only queries to heavy execution
engines). The framework enforces deterministic classification
(core/TASK_CLASSIFICATION.md:21-35).

Unverifiable Worker Completion Claims: Autonomous agents often
claim success without objective evidence. The system mandates
durable, inspectable proof artifacts
(workflows/handoff.md:98-106).

Accidental Git State Corruption: AI tools must never
autonomously commit, push, or rewrite repository history. Human
engineers hold exclusive Git mutation authority
(core/GIT_POLICY.md:5-23).

1.3 Main Design Principles

Minimize Unnecessary Context: Read only strictly relevant lines
and files. Context loader limits returned content to 200 lines and
16,384 UTF-16 string units plus truncation notices
(scripts/context-loader.ps1:28-29), loading specialized memory
files only when task classification warrants
(codex-anti core principles documentation:9).

Deterministic Routing: Every incoming task is evaluated against
a canonical six-field contract (INTENT, RISK, TARGET,
ALLOWLIST, REVIEW, TEST). Missing required fields block
execution (core/TASK_TEMPLATE.md:7-18).

Evidence-Based Verification: Completion claims require
reproducible, verifiable artifacts (status.json, result.md,
changed-files.txt, diff.patch, test-output-summary.md). Actual
workspace state strictly takes precedence over worker claims:
actual workspace > git diff > worker artifacts
(core/TASK_TEMPLATE.md:55).

Avoid Unnecessary Complexity (YAGNI & Ponytail Principle):
File-based workflow governance using PowerShell checks, Markdown,
and JSON; the external MCP bridge additionally uses Node.js and
DevTools. Strictly no vector databases, no background daemon
services, no persistent message queues, and no autonomous agent
schedulers (workflows/handoff.md:112-117).

2. Current Architecture

2.1 Complete Architectural Flow

flowchart TD
    Human["Human Engineer<br/>(Exclusive Git Authority & Final Approval)"]
    ChatWeb["ChatWeb<br/>(Browser-Only Planning / Analysis)"]
    Codex["Codex Desktop<br/>(Local Orchestrator & Evidence Verifier)"]
    AIWorkflow["AI-Workflow<br/>(Governance / Rules / Policies / Scripts)"]
    CodexAnti["codex-anti<br/>(Authoritative Project Memory & Invariants)"]
    Bridge["antigravity-local Bridge<br/>(CDP Port Discovery & Job Queue)"]
    Antigravity["Antigravity Desktop<br/>(Execution Worker)"]
    Artifacts["Durable Evidence Artifacts<br/>(status.json, result.md, diff.patch, etc.)"]
    Verification["Codex Verification Gate<br/>(scripts/evidence-check.ps1)"]

    Human -->|Prompt / Shortcut| ChatWeb
    ChatWeb -->|Clarified Scope / Spec| Codex
    Human -->|Direct Shortcut / Task Contract| Codex
    Codex -->|Progressive Context Resolution| AIWorkflow
    AIWorkflow -->|Authoritative Memory Root| CodexAnti
    Codex -->|Delegated Job Dispatch| Bridge
    Bridge -->|Job Submission Contract| Antigravity
    Antigravity -->|Execute Within Allowlist| Antigravity
    Antigravity -->|Emit Artifacts (ARTIFACT_READY)| Artifacts
    Artifacts -->|Read-Only Evidence Check| Verification
    Verification -->|Golden Path Provenance (verifiedBy: codex)| Codex
    Codex -->|Report & Normalized Output Block| Human
    Human -->|git add / git commit / git push| Human

2.2 Component Responsibilities and Boundaries Summary

Human Engineer: Defines intent, reviews diffs, makes release
decisions, and exclusively executes Git write operations
(core/GIT_POLICY.md:5-13).

ChatWeb: Browser-based interactive reasoning, architecture
planning, and trade-off analysis. Assigned a browser-only planning
role without local filesystem or shell execution in this workflow
(D:\AI\codex-anti\integrations\codex-chatgpt-web.md:5-9).

Codex Desktop: Local orchestrator and verifier. Ingests tasks,
resolves context, dispatches delegated jobs, validates worker
evidence, and writes non-executable documentation artifacts
(core/TASK_TEMPLATE.md:38-40).

AI-Workflow: Governance repository providing canonical task
contracts, five agent personas, five domain skills, ten prompt
shortcuts, and PowerShell verification scripts (README.md:1-37).

codex-anti: Centralized repository hosting the authoritative
project memory store (D:\AI\codex-anti\projects), architectural
decision records, and integration rules
(D:\AI\codex-anti\README.md:1-18).

antigravity-local Bridge: File-based job queue
(.antigravity-bridge/jobs/<job-id>/) integrated with Chrome
DevTools Protocol (CDP) port discovery
(scripts/start-antigravity.ps1:53-89,
scripts/bridge-check.ps1:49-86).

Antigravity Desktop: Execution worker performing
behavior-changing repository edits, code refactoring, and test
execution within approved allowlists, terminating at
ARTIFACT_READY (core/BRIDGE_POLICY.md:68-73).

Artifacts: Durable verification payload containing execution
metadata, results, file manifests, unified patches, and test counts
(workflows/handoff.md:98-106).

Codex Verification: Automated gate
(scripts/evidence-check.ps1,
scripts/bridge-golden-path-check.ps1) evaluating artifacts and
stamping provenance before lifecycle closure
(workflows/handoff.md:57-59).

3. Component Responsibilities

3.1 ChatWeb

Purpose: High-level reasoning, requirements clarification,
architecture evaluation, and cross-project scope alignment
(core/TASK_CLASSIFICATION.md:27).

Allowed Tasks: Brainstorming implementation options, analyzing
trade-offs, reviewing code snippets pasted by the user, drafting
initial task contracts, and structuring acceptance criteria
(D:\AI\codex-anti\integrations\codex-chatgpt-web.md:8).

Limitations: Under the repository integration policy,
browser-bound. Must never be expected to access local files, execute
shell commands, or run scripts. Does not use or require Codex
Native2, Full Harness MCP, custom API base URLs, or additional model
routing layers
(D:\AI\codex-anti\integrations\codex-chatgpt-web.md:7-16).

3.2 Codex Desktop

Orchestration: Intakes user requests, expands shorthand prompt
shortcuts (/fix, /feature, /audit, etc.) into canonical
six-field contracts, and coordinates multi-phase development
(core/TASK_CLASSIFICATION.md:12-18).

Routing: Evaluates task intent and classifies execution mode as
DIRECT (Codex execution), DELEGATED (Antigravity execution +
Codex verification), or HYBRID
(core/TASK_CLASSIFICATION.md:25-35).

Verification: Evaluates evidence artifacts emitted by delegated
workers using scripts/evidence-check.ps1, advancing verified jobs
to VERIFIED and CLOSED (workflows/handoff.md:57-59).

Context Usage: Invokes scripts/context-loader.ps1 to ingest
bounded project memory without prompt bloat (README.md:81-91).
Permitted to write documentation and non-executable artifacts
directly, but strictly prohibited from making behavior-changing
repository modifications (core/TASK_TEMPLATE.md:40).

3.3 AI-Workflow

Task Contracts: Defines the canonical six-field contract
(INTENT, RISK, TARGET, ALLOWLIST, REVIEW, TEST) in
core/TASK_TEMPLATE.md:9-18 and quick handoff aliases in
core/QUICK_TASK_TEMPLATE.md.

Lifecycle Governance: Maintains the unified six-state lifecycle
model in workflows/handoff.md:51-60.

Validation: Houses automated verification scripts in scripts/:
repository health (workflow-check.ps1), Git cleanliness
(git-check.ps1), diff boundaries (diff-check.ps1), release gates
(release-check.ps1), and bridge readiness (bridge-check.ps1).

Evidence Handling: Enforces the five-artifact bundle
(status.json, result.md, changed-files.txt, diff.patch,
test-output-summary.md) and formal failure waiver rules
(DEC-012, workflows/handoff.md:83-86).

Observability: Houses the validation schema for structured
execution metrics (context, handoff, performance,
validation) in scripts/evidence-check.ps1:490-638.

3.4 codex-anti

Project Memory Role: Houses the single authoritative project
memory root at D:\AI\codex-anti\projects (projects/ai-workflow/,
projects/codex-anti/, projects/jpaexercise-next/,
projects/markitdown/) (D:\AI\codex-anti\projects\README.md:1-6).

Context Storage Role: Maintains durable, living documentation
structured into standard memory files: summary.md,
architecture.md, decisions.md, issues.md, roadmap.md,
health.md, context.md, and changelog.md
(projects/ai-workflow/summary.md:35-43). Provides cross-agent
engineering principles
(codex-anti engineering principles documentation), context rules
(codex-anti context loading rules documentation), and browser
boundary definitions (integrations/codex-chatgpt-web.md).

3.5 Bridge (antigravity-local)

Communication Role: Coordinates cross-process handoffs between
Codex Desktop and Antigravity Desktop via file-based job folders
under .antigravity-bridge/jobs/<job-id>/ and Chrome DevTools
Protocol (CDP) connectivity (core/BRIDGE_POLICY.md:17-48).

Job Creation: Dispatches jobs using status.json as the
authoritative execution envelope and request.md as the compact
task body (core/BRIDGE_POLICY.md:18-36).

Artifact Handling: Ensures worker-emitted artifacts are
preserved in durable job directories for subsequent verification,
preventing lost execution state (workflows/handoff.md:98-106).

3.6 Antigravity Desktop

Execution Responsibility: Executes all behavior-changing
repository modifications: source code, unit/integration tests, UI
components, runtime configurations, database migrations, security
hardening, file upload logic, and dependency updates
(core/TASK_TEMPLATE.md:42, core/BRIDGE_POLICY.md:7).

Allowed Modifications: Strictly confined to explicit paths
declared in the task's ALLOWLIST. Any modification outside the
approved allowlist triggers validation failure
(core/AGENT_RULES.md:30-33).

Limitations: Generates artifacts and halts execution strictly at
ARTIFACT_READY. It is prohibited from self-advancing to VERIFIED
or CLOSED (core/BRIDGE_POLICY.md:68-73). Prohibited from
modifying the Antigravity installation itself
(AppData\Local\Programs\antigravity) and prohibited from mutating
Git history (core/BRIDGE_POLICY.md:100-102).

4. Lifecycle Model

4.1 Six Unified Lifecycle States

Task handoffs and bridge jobs advance through exactly six sequential
lifecycle states (workflows/handoff.md:51-64,
core/BRIDGE_POLICY.md:59-73):

CREATED  -->  SUBMITTED  -->  RUNNING  -->  ARTIFACT_READY  -->  VERIFIED  -->  CLOSED

Lifecycle State         Responsible Actor       State Definition & Authority Boundary

CREATED           Codex Desktop / User    Job request instantiated with task ID, target
workspace path, allowlist, and expected artifacts
(workflows/handoff.md:53).

SUBMITTED         Codex Desktop           Request validated and placed into the bridge queue
(.antigravity-bridge/jobs/<job-id>/) with
authoritative envelope status.json declaring
routingDecision=DELEGATED,
executor=antigravity, and target workspace
(workflows/handoff.md:54).

RUNNING           Antigravity Desktop     Antigravity worker actively inspects code, applies
edits within the allowlist, and executes
verification commands (workflows/handoff.md:55).

ARTIFACT_READY    Antigravity Desktop     Implementation complete. All five required durable
artifacts (result.md, changed-files.txt,
diff.patch, test-output-summary.md,
status.json) are generated in the job folder.
Antigravity halts at this state
(workflows/handoff.md:56,
core/BRIDGE_POLICY.md:68).

VERIFIED          Codex Desktop           Orchestrator runs scripts/evidence-check.ps1
against the job directory. If all five validation
checks pass,
scripts/bridge-golden-path-check.ps1 -Advance
advances state to VERIFIED, stamping durable
provenance verifiedBy: "codex"
(workflows/handoff.md:57,
scripts/bridge-golden-path-check.ps1:348-356).

4.2 Separation of Lifecycle, Validation, and Outcome

The framework strictly separates progression, validation results, and
closure outcomes (workflows/handoff.md:68-86): - Lifecycle State
(META.STATE): Tracks execution stage (CREATED, SUBMITTED,
RUNNING, ARTIFACT_READY, VERIFIED, CLOSED). - Validation
Result (STATUS / validation): Independent assessment of
correctness: - PASS: All required commands and contract gates passed
completely (or reconciled under an approved waiver). - FAIL: One or
more validation checks failed without an accepted waiver. - BLOCKED:
Execution or validation halted due to environment prerequisites or
infrastructure failure. - UNVERIFIED: Changes have not yet been
evaluated against the validation suite. - Task Closure Outcome
(outcome): - NORMAL: All acceptance criteria and tests passed
without waivers. - WAIVED: Completed with documented, accepted failure
waivers for pre-existing or out-of-scope issues with root-cause proof
(DEC-012, workflows/handoff.md:84-86).

4.3 Observed external-producer gap

The six states above are the implemented governance/verification
contract, not a guarantee about every external intermediate record. The
inspected bridge createJob writes state: "queued" and omits
workspace from its initial status object; markJobSubmitted writes
lowercase submitted
(C:\Users\My Laptop\plugins\antigravity-2\scripts\antigravity-local-mcp.js:884-918,1021-1032).
Final evidence must satisfy the workflow validator. Do not fabricate
closure or assume submission proves completion. ## 5. Routing Rules

5.1 Deterministic Provider Routing Matrix

Routing is evaluated through the five-step procedure defined in
core/TASK_CLASSIFICATION.md:21-54:

Provider Mode     Workflow Mode     Permitted Work Scope                    Bridge Requirement

Codex Direct  DIRECT          Read-only analysis, explanations, code  None. Operates locally in
review, architecture audits, debugging  target workspace
diagnosis, validation-only tasks, and   (core/TASK_TEMPLATE.md:40).
documentation/non-executable artifact
creation (core/TASK_TEMPLATE.md:40).

Antigravity   DELEGATED       All behavior-changing repository edits: Required. Mandatory bridge
source code, tests, UI, runtime         readiness check
configs, dependencies, database         (STATUS: PASS (READY)) prior
migrations, auth/security logic, and    to submission
release implementation                  (core/BRIDGE_POLICY.md:8).
(core/TASK_TEMPLATE.md:42).

5.2 Routing Boundaries & Invariants

Behavior-Changing Edits Mandate Antigravity: If a task alters
repository behavior, it routes to Antigravity even if the
modification touches only a single file
(core/TASK_TEMPLATE.md:47).

Codex-Direct Containment: Audit, architecture review, code
review, debugging analysis, and validation-only tasks remain
strictly Codex-direct (DIRECT) and cannot create Antigravity
bridge jobs unless implementation is explicitly requested
(core/TASK_CLASSIFICATION.md:29, core/BRIDGE_POLICY.md:7).

Write Allowlist Enforcement: Any write task missing an explicit,
non-empty ALLOWLIST blocks immediately (STATUS: BLOCKED)
(core/TASK_CLASSIFICATION.md:17).

Lane Isolation Rule: Missing or uncertain Antigravity bridge
readiness blocks only the Antigravity lane; Native Codex
analysis and ChatWeb planning continue unaffected
(core/TASK_TEMPLATE.md:44-46, core/BRIDGE_POLICY.md:7).

5.3 Observed routing differences

The matrix above describes AI-Workflow repository policy. The supplied
session orchestration policy also permits delegation of context-heavy
audits, while repository policy is stricter. The inspected external
bridge's getOffloadDecision can return HYBRID for ordinary code
modifications without explicit dual-provider intent; its @codex-only
branch is broader than the repository's prohibition on Codex
implementation
(C:\Users\My Laptop\plugins\antigravity-2\scripts\antigravity-local-mcp.js:365-520).
Thus routing cleanup is implemented in governance but not fully aligned
across the external helper. No routing changes are made here. ## 6.
Context Management System

6.1 Authoritative Memory Root

Project memory is centralized under a single authoritative memory
root: - Default Path: D:\AI\codex-anti\projects
(scripts/context-loader.ps1:33). - Environment Override:
Configurable via $env:PROJECT_MEMORY_ROOT for portability and testing
(scripts/context-loader.ps1:36-41). - Invariant: Strictly zero
repo-local fallback paths; prevents memory fragmentation and out-of-sync
context trees (scripts/context-loader.ps1:32).

6.2 Context Delivery Hierarchy

Context flows through a five-tier hierarchy from general to specific
(codex-anti context loading rules documentation:26-30):

Global Rules (core/AGENT_RULES.md, GIT_POLICY.md, TASK_TEMPLATE.md)
  ↓
Workflow Context (prompts/shortcuts.md, workflows/handoff.md)
  ↓
Project Memory (D:\AI\codex-anti\projects/<project>/summary.md, architecture.md, etc.)
  ↓
Task Context (Task description, shortcut parameters, explicit allowlist)
  ↓
Execution Context (Active file snippets, targeted compiler/test output)

6.3 Progressive Loading Mechanics

Bounded Ingestion: scripts/context-loader.ps1:28-29 declares
these output-limit constants per memory file:

MaxLinesPerFile = 200

MaxBytesPerFile = 16384 (16 KB) The implementation reads the
whole file with ReadAllLines, then truncates output using line
selection and .Length/Substring. Despite the variable name,
the second cap counts UTF-16 string units, not UTF-8 bytes;
notices add content. A strict 16-KB UTF-8 output ceiling and
bounded disk reads are NOT IMPLEMENTED
(scripts/context-loader.ps1:195-216).

Always Active: summary.md (compact project identity) is always
loaded by default (scripts/context-loader.ps1:108-110).

Conditional Loading Rules: Memory files are dynamically loaded
based on task intent classification
(scripts/context-loader.ps1:144-173):

feature / implement: loads context.md, architecture.md

bug / fix: loads context.md, issues.md

database / db: loads architecture.md, decisions.md

security: loads architecture.md, issues.md

planning: loads roadmap.md

history / release: loads decisions.md, changelog.md

health / audit: loads health.md

Domain Knowledge: workflow guidance selects relevant skills; the
memory loader itself only selects canonical memory files.

Manual @load Override: Supports explicit directives (e.g.,
@load architecture decisions) strictly allowlisted against
canonical memory file names. Traversal attempts (e.g.,
@load ../../secret) are rejected
(scripts/context-loader.ps1:118-142).

Avoiding Unnecessary Context: Memory metadata must never store
full file contents (scripts/evidence-check.ps1:545-547). Raw
database dumps, compiler binaries (.class, .jar), and target/
directories are strictly excluded
(D:\AI\codex-anti\integrations\codex-chatgpt-web.md:21-29).

6.4 Loader output details

SIZE_BYTES measures UTF-8 bytes of the returned file bodies, excluding
context labels and other output framing. Missing files produce
warnings/status text; the loader still ends with exit code 0. Callers
must examine the reported status and presence records. Manual @load
replaces automatic category selection while retaining summary
(scripts/context-loader.ps1:108-175,195-270). The five-tier hierarchy
is workflow guidance; the loader itself does not automatically ingest
all five tiers. ## 7. Project Memory Structure

The authoritative project memory directory
(D:\AI\codex-anti\projects/<project>/) organizes persistent knowledge
into standardized Markdown documents
(D:\AI\codex-anti\projects\ai-workflow\summary.md:35-43):

File Name               Mandatory / Conditional Purpose & Documented Scope

summary.md        Mandatory (Always       Compact project identity, repository root, tech
loaded)                 stack, active phase, active blockers, core
constraints, and index pointers to deeper
documents
(projects/ai-workflow/summary.md:1-43).

architecture.md   Conditional (feature, High-level system structure, subsystem
db, security)       breakdown, component boundaries, and pipeline
execution flows
(projects/ai-workflow/architecture.md:1-64).

decisions.md      Conditional (db,      Architectural Decision Records (ADRs) tracking
history)              ID, date, choice, rationale, and impact
(projects/ai-workflow/decisions.md:1-17).

issues.md         Conditional (bug,     Active and resolved defect tracking, operational
security)             risks, evidence, and remediation actions
(projects/ai-workflow/issues.md:1-10).

roadmap.md        Conditional             Chronological milestone progression, Phase
(planning)            closeouts, upcoming deliverables, and future
vision (projects/ai-workflow/roadmap.md:1-36).

health.md         Conditional (health,  Component verification matrix, health checks,
audit)                operational status, and maintenance notes
(scripts/context-loader.ps1:99).

context.md        Conditional (feature, Detailed environment setup, runtime
bug)                  prerequisites, and operational background
(scripts/context-loader.ps1:100).

8. Handoff and Evidence System

8.1 Durable Artifact Bundle

Delegated bridge execution requires six durable artifacts within
.antigravity-bridge/jobs/<job-id>/
(scripts/evidence-check.ps1:342-345, workflows/handoff.md:98-106):

request.md: Compact task body containing Goal, Intent, Scope,
Acceptance Criteria, and Tests. Redundant envelope metadata is
omitted (core/BRIDGE_POLICY.md:30).

status.json: Authoritative execution envelope defining
jobId, workspace, executor=antigravity,
routingDecision=DELEGATED, non-DIRECT workflowMode, canonical
state, artifact paths, test counts, and optional observability
(core/BRIDGE_POLICY.md:20-36).

result.md: Compact execution outcome summary (maximum 10
bullet points) detailing changes, identified risks, and recommended
next steps; must reference the task ID
(scripts/evidence-check.ps1:703-710).

changed-files.txt: Newline-delimited list of modified file
paths relative to project root, or NONE
(scripts/evidence-check.ps1:103-116).

diff.patch: Standard unified Git patch representing exact
modifications matching changed-files.txt; empty file if NONE
(scripts/evidence-check.ps1:71-101, 822-832).

test-output-summary.md: Focused test execution summary
declaring exact numeric counts for Total, Passed, and Failed
matching status.json (scripts/evidence-check.ps1:894-946).

8.2 Source of Truth & Evidence Verification

Authoritative Precedence:
actual workspace > git diff > worker artifacts (README.md:35,
core/TASK_TEMPLATE.md:55). If worker artifacts conflict with
actual workspace state, validation fails.

Authoritative Envelope: For bridge jobs, status.json is
authoritative over request.md for routing, workspace, and
lifecycle state (core/BRIDGE_POLICY.md:18-30).

Five-Pillar Evidence Validation Gate
(scripts/evidence-check.ps1):

Artifact Validation: Confirms presence and non-emptiness of
all required artifacts (evidence-check.ps1:340-403).

JSON Validation: Verifies JSON parsing, required bridge
properties, absolute workspace, and optional observability
structure (evidence-check.ps1:405-640).

Consistency Validation: Verifies task ID matching across
files, explicit validation status (PASS), and canonical
lifecycle state (evidence-check.ps1:643-802).

Scope Validation: Verifies changed-files.txt matches
diff.patch exactly and confirms all changed files adhere to
the task's ALLOWLIST without touching forbidden patterns
(evidence-check.ps1:805-879).

Test Validation: Confirms mathematical count consistency
between test-output-summary.md and status.json
(Total = Passed + Failed + Skipped), and reconciles any
waivers (evidence-check.ps1:882-960).

9. Observability

9.1 Implemented Observability Metrics

The framework implements a lightweight, optional structured
observability metadata schema within status.json under the
observability property, validated by
scripts/evidence-check.ps1:490-638:

{
  "observability": {
    "context": {
      "loadedFiles": ["summary.md", "context.md", "issues.md"],
      "sizeBytes": 9222
    },
    "handoff": {
      "requestBytes": 2732
    },
    "performance": {
      "start": "2026-09-16T05:23:33.780Z",
      "end": "2026-09-16T05:32:00.000Z",
      "durationMs": 506220
    },
    "validation": {
      "checksExecuted": 8,
      "aggregate": "PASS"
    }
  }
}

Context Metrics (context):

loadedFiles: Array of reported loaded memory file names. The
loader LOADED line lists selected files and can include missing
files; use its presence records to distinguish actual loads.
Non-array types fail validation (evidence-check.ps1:533-537).

sizeBytes: Genuine non-negative integer representing UTF-8
byte count of bounded context (evidence-check.ps1:539-544).

Memory Boundary Invariant: context metadata must never store
raw file content, content blocks, or full text
(evidence-check.ps1:545-547).

Handoff Metrics (handoff):

requestBytes: Genuine non-negative integer representing UTF-8
byte size of the request body (evidence-check.ps1:557-561).

Performance Metrics (performance):

durationMs: Genuine non-negative numeric duration in
milliseconds (evidence-check.ps1:572-576).

start / end: DateTime/DateTimeOffset values or non-empty
strings accepted by DateTimeOffset.TryParse
(evidence-check.ps1:578-589).

Validation Metrics (validation):

checksExecuted: Array of check names or genuine non-negative
integer count (evidence-check.ps1:599-605).

aggregate / result: Valid status string (PASS, FAIL,
BLOCKED, UNVERIFIED) matching top-level
status/validation properties (evidence-check.ps1:606-628).

9.2 Non-Implemented Observability Features

Prometheus / OpenTelemetry Exporters: NOT IMPLEMENTED.

Live Background Metrics Daemon: NOT IMPLEMENTED.

Telemetry Streaming Service: NOT IMPLEMENTED.

Historical jobs lacking observability remain completely valid;
observability is strictly an optional, fail-closed extension for new
bridge jobs (core/BRIDGE_POLICY.md:36, evidence-check.ps1:490).

9.3 Collection and verification boundary

The JSON above is a schema illustration, not measured evidence from this
audit. The loader implements context byte measurement, while
evidence-check.ps1 implements optional metadata validation. Automatic
end-to-end observability collection is NOT IMPLEMENTED in the inspected
external bridge createJob/markJobSubmitted path: those writers do
not populate observability. Execution must supply measurements; schema
acceptance does not prove their provenance. Missing observability is
permitted, but all other evidence requirements still apply.

The current timestamp helper accepts DateTime and DateTimeOffset as well
as parseable strings (scripts/evidence-check.ps1:517-525). This is
current source evidence, not a fresh self-check result. ## 10.
Validation System

The framework provides the following PowerShell verification scripts in
scripts/:

10.1 Workflow Integrity Validation (scripts/workflow-check.ps1)

Execution:
pwsh .\scripts\workflow-check.ps1 [-RepoPath <path>]

Scope: Evaluates framework integrity rules:

Required folders: agents, skills, prompts, core,
scripts (workflow-check.ps1:54-67).

Required policy files: AGENT_RULES.md, BRIDGE_POLICY.md,
GIT_POLICY.md, TASK_TEMPLATE.md, TASK_CLASSIFICATION.md,
QUICK_TASK_TEMPLATE.md, prompts/shortcuts.md
(workflow-check.ps1:69-91).

Canonical routing contract fields in core/TASK_TEMPLATE.md
(INTENT, RISK, TARGET, ALLOWLIST, REVIEW, TEST)
(workflow-check.ps1:93-107).

10 shortcut definitions in prompts/shortcuts.md
(workflow-check.ps1:109-124).

5 agent personas in agents/ and 5 domain skill modules in
skills/ (workflow-check.ps1:126-150).

Markdown link reference validity and external path leakage
detection (workflow-check.ps1:152-300).

Path Resolution: Features dynamic upward root traversal,
ensuring reliable execution when invoked from
Workflow System Audit or other subfolders
(workflow-check.ps1:29-48).

10.2 Context Loader Validation (scripts/context-loader-check.ps1)

Execution: pwsh .\scripts\context-loader-check.ps1

Scope: Includes assert-based checks:

Acceptance scenarios (bug fix, database design, @load
override) (context-loader-check.ps1:59-67).

Deterministic task classification rules (feature, security,
planning, history, health)
(context-loader-check.ps1:68-80, 117-122).

Path traversal safety and unapproved memory override rejection
(context-loader-check.ps1:81-83).

Non-destructive handling of empty or missing inputs
(context-loader-check.ps1:84-86).

Isolated temporary project test seams and line/byte truncation
limits (context-loader-check.ps1:91-115).

10.3 Evidence and Handoff Validation (scripts/evidence-check.ps1)

Execution:
pwsh .\scripts\evidence-check.ps1 -EvidenceDir <path> [-RequireTestSummary] [-SelfCheck]

Scope: Contains a built-in -SelfCheck fixture suite
(evidence-check.ps1:1230-1980). Validates real job directories
against five discrete pillars:

Artifact presence and non-emptiness.

JSON syntax, bridge execution envelope fields, and optional
observability.

Task ID matching, explicit status, and canonical lifecycle state
transitions.

Scope containment: diff vs. changed files vs. allowlists and
forbidden patterns.

Test consistency: mathematical count alignment and failure
waiver reconciliation.

Golden-path verification checks durable evidence, not a fresh replay of
Desktop execution. Its -Advance and -Close switches mutate
lifecycle/provenance fields; self-checks can create temporary fixtures.
No listed validation suite was run for this document.

10.4 Golden Path Verification (scripts/bridge-golden-path-check.ps1)

Execution:
pwsh .\scripts\bridge-golden-path-check.ps1 [-JobId <id>] [-Advance] [-Close]

Scope: End-to-end verifier testing real durable bridge jobs
across six authentic stages:

User task definition & intent in request.md.

Codex routing & contract envelope in status.json.

Bridge submission queue verification.

Antigravity execution verification (executor: antigravity).

Artifact generation verification (ARTIFACT_READY with 5
durable artifacts).

Codex evidence verification invoking evidence-check.ps1,
stamping provenance (verifiedBy: "codex",
closedBy: "codex").

11. Completed Optimizations

Completion is limited to the implemented policy/script portions below.
External generator alignment and universal metrics collection remain
incomplete, as described in sections 4, 5, 9, and 12. Benefits are
qualitative unless measurements are explicitly cited.

11.1 Unified Memory Root

Problem: Memory was fragmented across target repository
.ai/CONTEXT.md files, local scratch notes, and disparate
documentation trees, causing divergence and stale context
(D:\AI\codex-anti\projects\ai-workflow\issues.md:5).

Solution: Consolidated project-memory lookup into a single
authoritative memory root at D:\AI\codex-anti\projects
(configurable via $env:PROJECT_MEMORY_ROOT) and eliminated
repo-local fallback trees (scripts/context-loader.ps1:32-48).

Benefit: Provides a single authoritative source of truth across
all projects, reducing fragmented lookup; memory content can still
become stale.

11.2 Context Optimization

Problem: Monolithic context dumping bloated prompt sizes,
exhausted LLM token windows, increased latency, and diluted model
attention (D:\AI\codex-anti\projects\ai-workflow\decisions.md:14).

Solution: Implemented progressive loading in
scripts/context-loader.ps1: always load compact summary.md;
conditionally load specialized files per task intent; enforce strict
bounds (MaxLinesPerFile = 200,
MaxBytesPerFile = 16,384 string units in the implementation) with
explicit truncation notices
(scripts/context-loader.ps1:28-29, 208-212).

Benefit: Reduces unnecessary loaded content through task-based
selection. No percentage token saving or strict UTF-8 byte ceiling
is established by this inspection.

11.3 Handoff Compression

Problem: Redundant envelope metadata (workspace path, executor,
routing rules, artifact directories) was repeated across both
request.md and status.json, causing synchronization mismatches
and bulky handoffs (core/BRIDGE_POLICY.md:30).

Solution: Enforced strict separation of concerns: status.json
acts as the authoritative execution envelope, while request.md
serves as the compact task body containing only Goal, Intent, Scope,
Acceptance Criteria, and Tests (core/BRIDGE_POLICY.md:18-36).

Benefit: Allows compact handoff bodies and a single
authoritative envelope. The inspected external request generator
still appends redundant metadata, so universal payload reduction is
not established.

11.4 Routing Cleanup

Problem: Ambiguous routing classifications allowed read-only
tasks to inadvertently trigger heavy bridge execution jobs, while
subfolder command invocation caused path resolution failures
(core/BRIDGE_POLICY.md:7, scripts/workflow-check.ps1:29-48).

Solution: Formalized workflowMode: DIRECT for Codex read-only
work, DELEGATED for Antigravity modifications, and restricted
HYBRID strictly to explicit dual-provider tasks; added upward
directory traversal in PowerShell scripts
(core/TASK_CLASSIFICATION.md:25-35,
scripts/workflow-check.ps1:29-48).

Benefit: Clarifies intended provider ownership and lane
isolation. External heuristic differences remain; upward root
resolution applies to the scripts that implement it, not every
command.

11.5 Observability Integration

Problem: Lack of visibility into context size, handoff byte
overhead, execution duration, and test counts; historical attempts
caused schema mismatches during Phase 3.1 testing
(scripts/evidence-check.ps1:490-638).

Solution: Implemented an optional lightweight structured
metadata schema in status.json under observability validated by
scripts/evidence-check.ps1:490-638 (context, handoff,
performance, validation), while preserving full backwards
compatibility for historical jobs.

Benefit: Provides context-size output and optional metric
validation without an external metrics service. Automatic collection
on every job is not implemented.

12. Known Limitations

Only verified, codebase-grounded limitations are documented: 1.
External Bridge Payload Overhead: The external bridge request
builder appends routing/envelope metadata and artifact instructions even
though workflow validators accept a compact body
(C:\Users\My Laptop\plugins\antigravity-2\scripts\antigravity-local-mcp.js:852-882).
Transport uses Desktop DevTools connectivity as well as durable files;
payload overhead is not explained by absence of sockets. 2. No
Automatic Project Bootstrap Memory: Initializing a new target project
requires manually creating the project directory and summary.md under
D:\AI\codex-anti\projects; no automated CLI scaffolding or background
memory daemon exists (scripts/context-loader.ps1:56-94). 3. No
Dashboard: There is no web portal, graphical UI, or live status
dashboard for monitoring job queues or historical trend analysis
(workflows/handoff.md:114). 4. No AI Routing Layer: Task routing
is prescribed by Markdown policy and assisted by deterministic keyword
rules in the external bridge; no separate model-based routing service is
evidenced (core/TASK_CLASSIFICATION.md:21-35).

13. Recovery Guide

These instructions are for a future recovery. They were not executed
during this documentation task.

13.1 Install required tools

Install Git, PowerShell, Node.js on PATH, Codex Desktop, and Antigravity
Desktop on Windows. Restore account access through the applications. The
inspected bridge requires Node.js and a local Antigravity installation
(C:\Users\My Laptop\plugins\antigravity-2\README.md:30-53,
.mcp.json). Exact supported versions and clean-machine compatibility
are unknown here; use the user's verified installers/backups.

git --version
pwsh --version
node --version

The default Antigravity executable is
%LOCALAPPDATA%\Programs\antigravity\Antigravity.exe;
start-antigravity.ps1 -ExePath supports a different restored location.

13.2 Restore repositories and the separate bridge dependency

Restore backups or the user's known repository remotes to:

D:\AI-Workflow --- governance and scripts.

D:\AI\codex-anti --- project memory and integration documentation.

%USERPROFILE%\plugins\antigravity-2 --- executable bridge/plugin
source and manifest.

Repository URLs are UNKNOWN here; use verified remotes rather than
guessed URLs. Restore uncommitted memory and required historical job
artifacts from backup. A clone alone may not include them. Restoring
codex-anti does not restore the executable bridge.

Install/refresh the restored bridge plugin using the user's plugin
configuration as described by its README. Its source-documented setup
check is:

powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\antigravity-2\scripts\antigravity.ps1" setup

13.3 Restore MCP configuration, paths, and environment

Restore the user's backed-up Codex/plugin configuration, adjusting
profile paths. The inspected bridge .mcp.json registers:

antigravity_local: PowerShell launches node with
%USERPROFILE%\plugins\antigravity-2\scripts\antigravity-local-mcp.js.

antigravity_devtools: PowerShell invokes
%USERPROFILE%\plugins\antigravity-2\scripts\antigravity-devtools-mcp.ps1;
its environment sets CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1.

Use the restored manifest as the launcher source of truth. Active
host-specific registration and secrets were not copied into this
document. Confirm these tools appear in Codex after restoration.

If the memory root differs from the default, configure the actual
restored location:

[Environment]::SetEnvironmentVariable("PROJECT_MEMORY_ROOT", "D:\AI\codex-anti\projects", "User")
$env:PROJECT_MEMORY_ROOT = "D:\AI\codex-anti\projects"

Restore selected project directories and their memory files manually;
automatic project-memory bootstrap is NOT IMPLEMENTED by the loader. No
additional workflow credential variables were established by this
inspection. Restore application authentication and separately documented
project environments without placing secrets in this document.

Port resolution is explicit -Port, then
ANTIGRAVITY_PORT/DEVTOOLS_PORT, then runtime DevToolsActivePort
discovery. There is no implicit fixed-port fallback
(core/BRIDGE_POLICY.md:38-48).

13.4 Verify workflow and context

pwsh -NoProfile -File "D:\AI-Workflow\scripts\workflow-check.ps1" -RepoPath "D:\AI-Workflow"
pwsh -NoProfile -File "D:\AI-Workflow\scripts\context-loader-check.ps1"
pwsh -NoProfile -File "D:\AI-Workflow\scripts\evidence-check.ps1" -SelfCheck

Inspect failures/warnings and exit codes. Context checks require the
expected memory. Do not substitute historic results for current recovery
results or assume a fixed check count guarantees success.

13.5 Verify bridge readiness

Open Antigravity and establish a configured/discovered debugging port.
If no port exists on the fresh installation, choose and configure an
available port explicitly before using the starter; otherwise its bare
invocation fails closed.

pwsh -NoProfile -File "D:\AI-Workflow\scripts\start-antigravity.ps1"
pwsh -NoProfile -File "D:\AI-Workflow\scripts\bridge-check.ps1"

Require STATUS: PASS (READY) from the bridge check before delegation.
Resolve missing process, endpoint, active-page, and stale-session
problems. Retain the user's selected Desktop model. Do not substitute
headless agy execution unless explicitly requested.

13.6 Verify a real golden path

Use a real completed bridge job with the required evidence and matching
workspace. Checking a restored archive verifies evidence consistency,
not successful execution on the new machine. Fresh recovery proof
requires a scoped, authorized Desktop job and its resulting artifacts.

$recoveryJobDirectory = Read-Host "Absolute path to the real completed bridge job"
pwsh -NoProfile -File "D:\AI-Workflow\scripts\bridge-golden-path-check.ps1" -JobDirectory $recoveryJobDirectory

No real job means this gate cannot run. Do not manufacture artifacts or
mark closure manually. Use guarded advancement/closure only when
relevant validation and authorization are satisfied.

13.7 Unknown information

Exact repository remotes, backup completeness, installer provenance,
and compatible installed versions.

Active host MCP configuration and account setup beyond the inspected
plugin manifest.

Clean-machine recovery success and current full-suite results.

Whether every installed/cached bridge copy matches the inspected
external source.

Measured token/latency savings and universal metrics collection.

Resolve these from actual backups/configuration and recovery checks.
This is a recovery reference, not a completed recovery certification.

14. Future Modification Rules

14.1 Prohibitions (What NOT to Do)

Do NOT Add Unnecessary Agents: Retain the lean five canonical
roles in agents/ (architect, developer, reviewer,
security, tester). Reject speculative autonomous agent swarms or
redundant intermediary bots (workflows/handoff.md:115).

Do NOT Bypass Validation: Apply relevant contract and focused
validation gates to the change; documentation-only validation
follows its explicit task scope. Edits outside declared allowlists
fail closed (core/AGENT_RULES.md:30-33).

Do NOT Duplicate Memory Roots: Never create repo-local shadow
memory trees (.ai/memory/, .context/). Preserve
D:\AI\codex-anti\projects as the sole authoritative memory root
(scripts/context-loader.ps1:32-35).

Do NOT Mutate Lifecycle Without Migration: Do not introduce
ad-hoc intermediate lifecycle states. The six-state sequence
(CREATED -> SUBMITTED -> RUNNING -> ARTIFACT_READY -> VERIFIED -> CLOSED)
is enforced by contract validators (workflows/handoff.md:51-64).

Do NOT Perform Autonomous Git Mutations: AI agents must never
stage (git add), commit (git commit), push (git push), tag
(git tag), or alter branches. Git write authority belongs
exclusively to human engineers (core/GIT_POLICY.md:5-23).

14.2 Preferences (What to Prefer)

Prefer Minimal Changes (Ponytail Principle): Shortest safe
working diff wins. Delete dead code over adding abstractions. Choose
boring, proven patterns over clever complexity
(codex-anti engineering principles documentation:5).

Prefer Deterministic Rules: Rely on exact regex heuristics,
explicit allowlists, and fail-closed port resolution rather than
probabilistic LLM guesswork (core/TASK_CLASSIFICATION.md:21-54).

Prefer Measurable Improvements: Ground all architectural
improvements in concrete evidence: test tier verification, exact
byte counts, execution duration, and passing self-check test suites
(core/TEST_POLICY.md:1-50, scripts/evidence-check.ps1:490-638).
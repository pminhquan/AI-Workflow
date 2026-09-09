# Domain Skill: Release

## Overview
Guidelines and domain-specific practices for release readiness validation, release candidate audits, artifact integrity checks, and pre-deployment gate verification.

## 1. When to Use
- Validating release readiness and verifying all release tier gates prior to human tag or deployment.
- Auditing release candidate artifacts, manifests, changelogs, and version metadata for consistency.
- Running read-only pre-release verification scripts across git repositories and build outputs.
- Preparing release documentation, verification evidence, and rollback procedures for human sign-off.

## 2. Required Context
- Target release version, milestone identifier, and target release branch.
- Required release artifacts (e.g., binaries, archives, documentation, changelog entries).
- Applicable verification tier requirements and required gate checklists (e.g., Tier 4 release suite).
- Verification tools, static analysis gates, and clean working tree expectations.

## 3. Common Risks
- Releasing from an untracked, dirty, or detached Git working tree state.
- Version number inconsistencies between code descriptors, manifests, documentation, and release tags.
- Missing or outdated release notes, changelog records, or migration instructions.
- Undetected test regressions or skipped verification gates leading to production failure.
- Accidental inclusion of sensitive debug artifacts, credentials, or private configuration files in release bundles.

## 4. Testing Expectations
- **Clean Working Tree**: Verify working tree has no uncommitted, untracked, or unexpected modifications via read-only checks.
- **Full Test Suite Execution**: Verify 100% passing results across the complete project test suite (Tier 4 Release gate).
- **Artifact Presence**: Confirm all expected build outputs, checksums, and documentation files exist and are non-empty.
- **Rollback Readiness**: Ensure migration rollback steps or rollback documentation are verified and documented.

## 5. Forbidden Actions
- No automated `git tag`, `git push`, `git commit`, `git release`, or version control mutations by AI agents.
- No triggering live deployments, publishing packages, or uploading artifacts to production distribution endpoints.
- No committing release credentials, signing keys, certificates, or deployment passwords.
- No bypassing or suppressing failing test results or incomplete checklist items to force a passing release state.

## 6. Release Verification CLI & Evidence Model

The framework provides an evidence-based release validation gate via `scripts/release-check.ps1`.

### CLI Usage

```powershell
# Safe-mode inspection (read-only audit)
./scripts/release-check.ps1 -SafeMode

# Full evidence-based release candidate gate verification
./scripts/release-check.ps1 -RepoPath "/path/to/project" `
    -RequireClean `
    -RequireBranch "main" `
    -TestTier 4 `
    -TestEvidence "PASS (142 tests passed, 0 failures)" `
    -ArtifactPath "dist/app.jar" `
    -SmokeEvidence "PASS (Health endpoint returned 200 OK)"
```

### CLI Parameters
- `-RepoPath`: Target repository path (defaults to current directory).
- `-RequireClean`: Enforces zero uncommitted changes (default: `$true`).
- `-RequireBranch`: Optional expected branch name (e.g., `main`, `release/*`).
- `-RequiredFiles`: Array of mandatory file paths (default: `@('README.md')`).
- `-TestTier`: Declared verification tier (0 to 4; default: 4).
- `-TestEvidence`: Test log file path or summary string.
- `-AllowSkippedTests`: Permits skipped tests without failing the gate (dry-run mode).
- `-ValidateBuild`: Explicitly validates build outcome/execution (requires `-BuildEvidence`; fails closed if absent).
- `-BuildTool`: Optional build tool override (`mvn`, `gradle`, `npm`, etc.).
- `-BuildEvidence`: Build log file path or summary string (required when `-ValidateBuild` is specified).
- `-ArtifactPath`: Path to release artifact file to validate.
- `-SupportedArtifactExtensions`: Allowed extensions (`.jar`, `.war`, `.zip`, `.tar.gz`, etc.).
- `-SmokeEvidence`: Smoke test log path or summary string.
- `-SafeMode`: Non-blocking audit inspection mode (never claims all gates passed).

### Evidence Model
1. **Source Evidence (`SOURCE_VALIDATION: PASS | FAIL`)**:
   - `GIT_VALIDATION`: Verifies repository validity, current branch, commit SHA, clean working tree, and absence of unexpected untracked release files/binaries, with exit code verification on all Git operations.
   - `BUILD_VALIDATION`: Detects build tools and wrappers, reflecting Maven wrapper (`mvnw`) priority; validates build execution only when explicitly requested via `-ValidateBuild`, requiring verifiable `-BuildEvidence` (fails closed if evidence is absent).
   - `TEST_VALIDATION`: Enforces declared `TestTier` and distinguishes `SKIPPED` from `PASSED`.
   - `REQUIRED_FILES`: Verifies all mandatory release files exist.
2. **Artifact Evidence (`ARTIFACT_VALIDATION: PASS | FAIL`)**:
   - Explicit artifact path provided.
   - Existing regular file verified.
   - Supported package format confirmed.
   - Non-zero file size verified.
   - SHA-256 cryptographic checksum computed and recorded.
3. **Runtime Evidence (`RUNTIME_VALIDATION: VERIFIED | UNVERIFIED`)**:
   - Requires verified smoke test evidence (logs, HTTP 200 responses, health check outputs).
   - Normal release gates fail closed (`exit 1`) while runtime is `UNVERIFIED`; `SafeMode` remains non-blocking (`exit 0`) but never claims all gates passed.
4. **Human Decision Boundary**:
   - Final release decisions, Git tagging, and production deployments remain exclusively the responsibility of the human engineer.

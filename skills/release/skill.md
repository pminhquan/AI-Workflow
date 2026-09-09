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

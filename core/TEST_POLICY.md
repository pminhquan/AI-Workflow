# Test Policy and Verification Gates

This policy establishes tiered verification gates to ensure changes are validated at the appropriate depth before human review and merge.

## 1. Verification Tiers

| Tier | Category | Target Scope | Required Verification | Minimum Gate Criteria |
|---|---|---|---|---|
| **Tier 0** | **Docs & Static** | Documentation, markdown, comments, static configuration | Syntax parse, linting, format validation, link/reference check | No syntax errors; linter passes; references valid |
| **Tier 1** | **UI** | User interfaces, components, styling, templates, presentation | Component rendering, visual consistency, layout, accessibility | Components render without error; layout matches spec |
| **Tier 2** | **Logic** | Business logic, state machines, utilities, algorithms, data parsing | Unit tests, boundary conditions, edge-case assertions | All unit tests pass; regressions covered by test |
| **Tier 3** | **Security / Database / Risky** | Auth, permissions, crypto, input validation, DB schemas, concurrency | Integration tests, security boundary tests, migration checks | Threat mitigation tested; zero permission leaks; migrations reversible |
| **Tier 4** | **Release** | Release candidate, deployment readiness, full package build | Comprehensive test suite, build artifact validation, smoke tests | 100% test suite pass; clean build; no unresolved blockers |

## 2. Tier Details and Requirements

### Tier 0: Docs & Static
- **Applicability**: Changes consisting only of text files, documentation, markdown files, and static non-executable configuration.
- **Verification Method**:
  - Run syntax/schema parser on modified files.
  - Verify markdown structure, headings, and internal links.
  - Confirm no unintentional changes or formatting corruption.

### Tier 1: UI
- **Applicability**: Front-end components, templates, stylesheet updates, UI layout adjustments.
- **Verification Method**:
  - Verify component compilation and build.
  - Validate DOM structure or UI component test suite.
  - Check responsiveness and basic accessibility considerations.

### Tier 2: Logic
- **Applicability**: Standard business logic, functional enhancements, bug fixes, algorithmic changes.
- **Verification Method**:
  - Execute existing unit tests covering the modified area.
  - Add or update tests asserting the new behavior or bug fix.
  - Ensure zero regressions in adjacent tests.

### Tier 3: Security / Database / Risky
- **Applicability**: Changes touching authorization, authentication, cryptography, input parsing, data models, persistence, migration scripts, or shared critical paths.
- **Verification Method**:
  - Validate input boundaries and reject malformed inputs.
  - Verify authorization checks cannot be bypassed.
  - Test data migration forwards and backwards (rollback) where applicable.
  - Verify error handling does not expose internal stack traces or sensitive data.

### Tier 4: Release
- **Applicability**: Pre-release milestones, version cut-offs, production candidates.
- **Verification Method**:
  - Full project test suite execution.
  - Release artifact build verification.
  - Clean working tree verification (read-only checks).
  - Validation that all open task gates are satisfied.

## 3. General Testing Rules
1. **Inheritance**: A higher tier inherits all verification requirements of preceding tiers.
2. **Minimal & Targeted**: Test changes should be focused on the modified behavior without rewriting entire unrelated test suites.
3. **Runnable Evidence**: AI assistants must execute tests locally and record exact pass/fail counts in the standard `TEST:` output field.
4. **No Test Erasure**: Never delete or comment out failing tests to achieve a passing gate; investigate and resolve the underlying issue.

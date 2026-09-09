# Domain Skill: Frontend

## Overview
Guidelines and domain-specific practices for client-side user interface development, web components, styling, responsive layouts, and browser client interactions.

## 1. When to Use
- Implementing or updating user interface components, templates, layouts, or visual assets.
- Modifying client-side styling, stylesheets, responsive breakpoints, or theming tokens.
- Handling client-side user interaction, form validation, event listeners, and UI state management.
- Addressing accessibility (a11y) requirements, browser compatibility issues, or visual rendering bugs.

## 2. Required Context
- Target browser compatibility requirements and display targets (desktop, tablet, mobile).
- Existing component architecture, layout conventions, and styling methodologies.
- Client-side build configuration, asset pipeline, and module bundling setup.
- Accessibility standards (e.g., WCAG conformance level) and interaction patterns expected.

## 3. Common Risks
- Cross-site scripting (XSS) vulnerabilities caused by unsanitized HTML injection or unsafe DOM manipulation.
- Responsive layout breakage across unexpected viewport dimensions or screen resolutions.
- Memory leaks from uncleaned event listeners, intervals, or dangling references in long-lived client pages.
- Accessibility failures (missing semantic elements, broken keyboard navigation, poor color contrast).
- Performance regressions resulting from excessive DOM re-renders or unoptimized asset bundles.

## 4. Testing Expectations
- **Component Rendering**: Verify UI components render cleanly without console warnings or runtime exceptions.
- **Visual & Layout Check**: Validate visual alignment across target responsive breakpoints.
- **Interaction Testing**: Test user interactions, form validation error states, and keyboard navigation.
- **Tier Compliance**: UI-only adjustments fall under Tier 1 (UI); components with complex client logic require Tier 2 (Logic).

## 5. Forbidden Actions
- No embedding sensitive tokens, API secrets, or private keys into client-facing bundles or markup.
- No bypassing framework sanitization mechanisms (e.g., raw HTML insertion) without verified sanitization.
- No adding heavy external UI libraries or component bundles without explicit human authorization.
- No automatic Git mutations (`git add`, `git commit`, `git push`, etc.) or automatic deployment triggers.

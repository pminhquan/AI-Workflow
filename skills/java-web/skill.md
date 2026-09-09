# Domain Skill: Java Web

## Overview
Guidelines and domain-specific practices for developing, auditing, and maintaining Java-based web applications, REST services, and web backend components.

## 1. When to Use
- Implementing or modifying HTTP endpoints, REST APIs, or controller logic in Java web services.
- Updating service-layer business logic, request/response data transfer objects (DTOs), or validation annotations.
- Configuring web filters, interceptors, middleware, or dependency injection bindings.
- Troubleshooting web application runtime issues, serialization failures, or HTTP status mapping.

## 2. Required Context
- Target Java version and servlet/web runtime environment.
- Standard build configuration (e.g., build descriptor files, dependency definitions).
- API contracts, request/response schema specifications, and expected status codes.
- Existing packaging conventions, package naming patterns, and dependency injection framework in use.

## 3. Common Risks
- Classpath conflicts, conflicting transitive dependencies, or binary incompatibilities.
- Thread-safety violations when using shared mutable singletons or static state in concurrent servlet containers.
- Unhandled null pointer exceptions or improper optional unwrapping in service layers.
- Insecure deserialization or improper JSON/XML payload parsing.
- Resource leaks resulting from unclosed streams, database connections, or socket handles.

## 4. Testing Expectations
- **Unit Testing**: Unit tests verifying controller endpoint responses, DTO validation, and service logic.
- **Mocking & Isolation**: Mock external services and dependencies cleanly to test isolated behavior.
- **Edge Cases**: Assert behavior for empty payloads, malformed JSON, boundary values, and error status codes.
- **Tier Compliance**: Typically requires Tier 2 (Logic) or Tier 3 (Security/Database) verification depending on functionality.

## 5. Forbidden Actions
- No hardcoded database credentials, API tokens, passwords, or personal filesystem paths in source or configuration files.
- No modifying build descriptors to introduce unapproved third-party dependencies without prior human consent.
- No catching and swallowing exceptions silently without logging or appropriate error responses.
- No automatic Git mutations (`git add`, `git commit`, `git push`, etc.) or automated deployment executions.

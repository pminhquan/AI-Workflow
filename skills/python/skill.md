# Domain Skill: Python

## Overview
Guidelines and domain-specific practices for developing, testing, and maintaining Python applications, services, scripts, and libraries.

## 1. When to Use
- Implementing or refactoring Python modules, functions, classes, and packages.
- Updating CLI tools, background workers, asynchronous tasks, or API services written in Python.
- Adding type annotations, data modeling, validation schemas, or serialization logic.
- Debugging Python runtime exceptions, performance bottlenecks, or concurrency issues.

## 2. Required Context
- Target Python interpreter version and runtime environment.
- Project packaging structure, virtual environment configuration, and dependency management format.
- Existing codebase conventions regarding typing, asynchronous execution (asyncio vs. synchronous), and logging.
- Module interfaces, function signatures, and expected input/output data types.

## 3. Common Risks
- Dynamic typing pitfalls and runtime `AttributeError` or `TypeError` due to missing or inaccurate type checks.
- Mutable default argument values causing unexpected state retention across function invocations.
- Scope shadowing and global state contamination across concurrently executing coroutines or threads.
- Unpinned or conflicting package dependencies causing subtle environment divergence.
- Unhandled exceptions resulting in unhandled process crashes or resource exhaustion.

## 4. Testing Expectations
- **Unit Testing**: Unit tests covering modified functions, edge cases, and failure branches.
- **Type Checking**: Verification of type hints and signature compatibility where typing is used.
- **Assertion Coverage**: Explicit assertions testing `None` handling, empty sequences, boundary values, and exception raising.
- **Tier Compliance**: Execute Tier 2 (Logic) test suites for business logic changes or Tier 3 for risky components.

## 5. Forbidden Actions
- No hardcoded secrets, connection strings, credentials, or personal workstation paths.
- No installing global system packages or modifying environment variables outside project test isolation.
- No using bare `except:` clauses that catch and suppress system-exiting exceptions or unrelated errors.
- No automatic Git mutations (`git add`, `git commit`, `git push`, etc.) or automatic deployment triggers.

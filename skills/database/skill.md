# Domain Skill: Database

## Overview
Guidelines and domain-specific practices for database schema evolution, migration authoring, query optimization, and data persistence layers.

## 1. When to Use
- Authoring or modifying database migration scripts, table schemas, views, or indexes.
- Writing or optimizing queries, data access objects, repositories, or ORM mappings.
- Designing data models, constraints (foreign keys, uniqueness, check constraints), and transaction boundaries.
- Troubleshooting data integrity issues, deadlocks, lock contention, or slow query performance.

## 2. Required Context
- Target database engine and dialect version.
- Existing schema design, naming conventions, and migration tool in use.
- Data volume profile, indexing strategy, and read/write performance requirements.
- Transaction isolation levels and consistency guarantees expected by the application.

## 3. Common Risks
- Table locks and prolonged schema migrations causing downtime or request timeouts on large tables.
- Irreversible destructive operations (e.g., dropping columns or tables without a staged transition).
- Missing indexes causing full table scans and performance degradation under load.
- SQL injection vulnerabilities stemming from unparameterized query concatenation.
- Data inconsistency or orphan records due to missing foreign key constraints or incomplete transactions.

## 4. Testing Expectations
- **Migration Reversibility**: Verify migrations execute successfully forward and backward (down/rollback) where supported.
- **Query Verification**: Test query correctness, parameter binding, and result set mapping with test fixtures.
- **Boundary & Null Checks**: Verify behavior with null fields, duplicate unique key attempts, and constraint violations.
- **Tier Compliance**: Database schema and persistence changes strictly require Tier 3 (Security / Database / Risky) verification.

## 5. Forbidden Actions
- No hardcoded database credentials, connection strings, hostnames, or production connection parameters.
- No unparameterized dynamic SQL constructed via string formatting or concatenation.
- No destructive commands (`DROP TABLE`, `TRUNCATE`, `DROP COLUMN`) without explicit human architectural approval and migration plan.
- No automatic Git mutations (`git add`, `git commit`, `git push`, etc.) or direct deployment to live database instances.

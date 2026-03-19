# Skill: Regression Testing & Bug Triage

> Load this skill when: Code changes need to be verified against existing
> functionality, or bugs need classification and routing.

## Context

In 100% AI development, regressions are silent killers. An agent fixes one bug
and introduces three more. Every code change must be tested against the FULL
existing test suite. Every bug must be classified, root-caused, and routed to
the right agent with enough context to fix it without asking questions.

## Regression Testing Protocol

### Phase 1: Change Impact Analysis

Before running tests, understand WHAT changed:

```
CHANGE IMPACT ANALYSIS:

Files Changed: [list from git diff]

IMPACT MAP:
  Changed File → What it affects → What tests to run

  domain/services/user_service.py
    → User creation, validation, profile updates
    → tests/unit/test_user_service.py (ALL tests)
    → tests/integration/test_users_api.py (ALL tests)
    → tests/e2e/test_registration_flow.py

  api/schemas/user_schemas.py
    → Request/response serialization
    → tests/unit/test_user_schemas.py
    → tests/integration/test_users_api.py (schema validation)
    → Contract tests (schema compliance)

  infrastructure/repositories/user_repository.py
    → Database queries, data access
    → tests/unit/test_user_repository.py
    → tests/integration/test_users_api.py
    → Performance tests (query timing)

RISK ASSESSMENT:
  High Risk Changes (run FULL test suite):
    - Domain logic changes
    - Database schema changes
    - Authentication/authorization changes
    - API contract changes
    - Shared utility changes

  Medium Risk Changes (run related + integration tests):
    - Single endpoint changes
    - UI component changes
    - Configuration changes

  Low Risk Changes (run related unit tests):
    - Comment/doc changes
    - Logging changes
    - Test-only changes
```

### Phase 2: Regression Test Execution

```
EXECUTION ORDER:

1. UNIT TESTS (fast — run ALL, always)
   Command: pytest tests/unit/ -v --tb=short
   Timeout: 2 minutes
   Gate: ALL must pass

2. INTEGRATION TESTS (medium — run ALL for high-risk, impacted for medium-risk)
   Command: pytest tests/integration/ -v --tb=short
   Timeout: 5 minutes
   Gate: ALL must pass

3. CONTRACT TESTS (verify API schemas haven't drifted)
   Command: pytest tests/contract/ -v
   Timeout: 2 minutes
   Gate: ALL must pass

4. E2E TESTS (slow — run critical paths always)
   Command: playwright test --project=chromium
   Timeout: 10 minutes
   Gate: Critical paths must pass

5. SMOKE TESTS (post-deployment quick check)
   Health endpoint responding
   Can create a user
   Can authenticate
   Can fetch profile

RESULT ANALYSIS:
  All pass → REGRESSION CLEAR ✅
  New failures → REGRESSION DETECTED ❌ → Bug Triage
  Flaky tests → INVESTIGATE 🔍 → Fix flaky test first
```

### Phase 3: Bug Triage Protocol

When a test fails, classify it:

```
BUG TRIAGE DECISION TREE:

1. Is the test correct?
   NO  → Fix the test (false positive)
   YES → Continue

2. Was this working before the change?
   YES → REGRESSION BUG (caused by this change)
   NO  → PRE-EXISTING BUG (was already broken)

3. What's the severity?

   CRITICAL (P0) — Production blocker:
     - Data loss or corruption
     - Security vulnerability
     - Complete feature failure
     - Authentication bypass
     Action: Stop sprint. Fix immediately. Assign to original agent.

   HIGH (P1) — Major functionality broken:
     - Core user flow broken
     - API contract violation
     - Business rule not enforced
     - Accessibility barrier
     Action: Fix before sprint completion. Block release.

   MEDIUM (P2) — Feature partially broken:
     - Edge case not handled
     - UI inconsistency
     - Performance degradation (but within 2x target)
     - Non-critical validation missing
     Action: PM decides: fix now or defer to next sprint.

   LOW (P3) — Minor issue:
     - Cosmetic defect
     - Typo in error message
     - Logging missing
     - Code style inconsistency
     Action: Add to backlog. Don't block release.
```

### Phase 4: Bug Report Template

```markdown
## BUG-[NNN]: [Title — Clear, specific description]

**Severity:** CRITICAL | HIGH | MEDIUM | LOW
**Type:** Regression | New Bug | Pre-existing
**Found in:** [Test name / manual check]
**Caused by:** [Git commit or "Unknown"]
**Assigned to:** [agent name]

### Steps to Reproduce
1. [Exact step with specific data]
2. [Exact step]
3. [Exact step]

### Expected Result
[What should happen — reference acceptance criteria]

### Actual Result
[What actually happens — include error messages, status codes]

### Evidence
```
[Test output, error log, stack trace]
```

### Root Cause Analysis
[WHY it broke — not just WHAT broke]
- Changed function X, which is called by Y, which caused Z to fail
- Or: Missing null check when data is empty

### Suggested Fix
[Specific guidance for the fixing agent]
- File: [path]
- Line: [number]
- Change: [description]

### Regression Test
[Test to add that would have caught this]
```gherkin
Scenario: [Name]
  Given [precondition]
  When [action]
  Then [expected result that now fails]
```
```

### Phase 5: Flaky Test Resolution

```
FLAKY TEST DETECTION:
  A test that passes sometimes and fails sometimes.

INVESTIGATION PROTOCOL:
  1. Run the test 10 times in isolation
  2. Check for these common causes:

  TIMING-DEPENDENT:
    Symptom: Test passes locally, fails in CI
    Cause: Hardcoded sleep, race condition, timeout too short
    Fix: Use condition-based waits, not time-based

  ORDER-DEPENDENT:
    Symptom: Test passes alone, fails when run with others
    Cause: Shared state (database, global variable, file)
    Fix: Isolate test data, use fresh fixtures

  ENVIRONMENT-DEPENDENT:
    Symptom: Test passes on one machine, fails on another
    Cause: Different OS, timezone, locale, package version
    Fix: Pin dependencies, use UTC, explicit locale

  EXTERNAL-DEPENDENT:
    Symptom: Test fails randomly
    Cause: External API, network, DNS resolution
    Fix: Mock external dependencies in unit/integration tests

  RESOLUTION RULE:
    Fix the flaky test BEFORE investigating other failures.
    A flaky test masks real bugs.
```

## Output Format

```json
{
  "regression_run": "RUN-2026-03-19-001",
  "trigger": "PR merge — user profile update feature",
  "change_risk": "high",
  "results": {
    "unit": { "total": 142, "passed": 142, "failed": 0 },
    "integration": { "total": 38, "passed": 37, "failed": 1 },
    "contract": { "total": 15, "passed": 15, "failed": 0 },
    "e2e": { "total": 8, "passed": 8, "failed": 0 }
  },
  "regressions_found": 1,
  "bugs_filed": [
    {
      "id": "BUG-012",
      "severity": "high",
      "title": "Profile update returns 500 when name contains apostrophe",
      "assigned_to": "backend_dev",
      "caused_by": "commit abc123"
    }
  ],
  "flaky_tests": 0,
  "gate_decision": "FAIL — 1 high-severity regression"
}
```

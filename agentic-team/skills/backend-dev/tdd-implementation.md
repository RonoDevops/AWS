# Skill: Test-Driven Development (TDD) for AI Agents

> Load this skill when: Implementing any backend feature. TDD is MANDATORY —
> no production code exists without a failing test first.

## Context

In 100% AI development, TDD is your safety net. There's no human to manually test
your code, no QA tester clicking through flows, no developer reading your code
before it runs. Tests are the ONLY proof that your code works. Skip TDD and
you ship bugs blindly.

## TDD Protocol (The Iron Cycle)

### The Cycle: RED → GREEN → REFACTOR

```
STEP 1 — RED (Write a Failing Test)
  ┌────────────────────────────────────────────────┐
  │ Write a test that:                              │
  │ • Tests ONE behavior from the acceptance criteria│
  │ • Fails for the RIGHT reason (not import error)  │
  │ • Uses descriptive name: test_[action]_[condition]_[result] │
  │ • Has clear assertions (not just "no exception") │
  │                                                  │
  │ RUN THE TEST → IT MUST FAIL                     │
  │ If it passes → your test is wrong (tests nothing) │
  └────────────────────────────────────────────────┘
           │
           ▼
STEP 2 — GREEN (Write Minimum Code to Pass)
  ┌────────────────────────────────────────────────┐
  │ Write the SIMPLEST code that makes the test pass│
  │ • Don't optimize                                │
  │ • Don't handle edge cases not yet tested         │
  │ • Don't refactor yet                            │
  │ • Hardcode if that makes the test pass          │
  │ • It's OK if the code is ugly                   │
  │                                                  │
  │ RUN ALL TESTS → ALL MUST PASS                   │
  │ If any fail → fix before moving on              │
  └────────────────────────────────────────────────┘
           │
           ▼
STEP 3 — REFACTOR (Clean Up Without Changing Behavior)
  ┌────────────────────────────────────────────────┐
  │ Now improve the code:                           │
  │ • Remove duplication                            │
  │ • Extract methods/classes                       │
  │ • Improve naming                                │
  │ • Apply patterns                                │
  │ • But DO NOT add new behavior                   │
  │                                                  │
  │ RUN ALL TESTS → ALL MUST STILL PASS             │
  │ If any fail → your refactor changed behavior    │
  └────────────────────────────────────────────────┘
           │
           ▼
  REPEAT with next acceptance criterion
```

### Test Naming Convention

```python
# Pattern: test_[unit]_[scenario]_[expected_result]

# Good:
def test_create_user_with_valid_data_returns_user_with_id():
def test_create_user_with_duplicate_email_raises_conflict_error():
def test_create_user_with_short_password_raises_validation_error():
def test_get_user_with_valid_id_returns_user():
def test_get_user_with_nonexistent_id_raises_not_found():
def test_order_total_equals_sum_of_line_totals():
def test_order_with_zero_lines_raises_invariant_error():

# Bad:
def test_user():              # What about the user?
def test_create():            # Create what?
def test_error_handling():    # Which error?
def test_it_works():          # What works?
```

### Test Structure (AAA Pattern)

```python
def test_create_user_with_valid_data_returns_user_with_id():
    # ARRANGE — Set up test data and dependencies
    user_data = {
        "email": "jane@example.com",
        "password": "SecureP@ss123",
        "name": "Jane Doe"
    }
    repo = InMemoryUserRepository()
    service = UserService(repo=repo)

    # ACT — Execute the operation under test
    result = service.create_user(user_data)

    # ASSERT — Verify the outcome
    assert result.id is not None
    assert result.email == "jane@example.com"
    assert result.name == "Jane Doe"
    assert result.status == "pending"
    assert result.created_at is not None
    # Verify side effects
    assert repo.find_by_id(result.id) is not None
```

### Test Categories & When to Write Each

```
UNIT TESTS (75% of tests — write these during TDD):
  What:  Test a single function/method in isolation
  Speed: < 10ms each
  Deps:  No database, no network, no filesystem
  Mock:  External dependencies (repos, APIs, queues)
  When:  EVERY TDD cycle

  Example:
    test_calculate_order_total_sums_line_totals()
    test_validate_email_rejects_invalid_format()
    test_password_hash_is_not_plaintext()

INTEGRATION TESTS (20% — write after unit tests pass):
  What:  Test components working together
  Speed: < 1s each
  Deps:  Real database (test instance), real filesystem
  Mock:  External APIs only
  When:  After implementing a complete endpoint/feature

  Example:
    test_post_users_creates_user_in_database()
    test_post_users_returns_409_for_duplicate_email()
    test_get_users_returns_paginated_results()

E2E TESTS (5% — written by QA agent, not during TDD):
  What:  Full user journey through the system
  Speed: < 10s each
  Deps:  Full system running
  Mock:  Nothing (maybe external payment APIs)
  When:  QA agent writes these after all dev tasks done
```

### Anti-Patterns to Avoid

```
❌ TESTING AFTER CODING
  "I'll write tests after the implementation"
  → Tests become an afterthought, miss edge cases, test implementation not behavior

❌ TESTING IMPLEMENTATION DETAILS
  Bad:  assert service._internal_cache == {...}
  Good: assert service.get_user(id) == expected_user

❌ TESTING FRAMEWORK CODE
  Don't test that SQLAlchemy saves to the database.
  Test YOUR logic: the service creates a user with correct defaults.

❌ MULTIPLE ASSERTIONS ON DIFFERENT BEHAVIORS
  Bad:  One test that checks creation AND validation AND error handling
  Good: Three tests, one for each behavior

❌ SKIPPING THE RED STEP
  If your test passes immediately, it's testing nothing.
  Always see it fail first.

❌ OVER-MOCKING
  If you mock everything, you're testing nothing.
  Mock boundaries (DB, APIs), not internal collaborators.

❌ FRAGILE TESTS
  Bad:  assert response.body == '{"id":"550e8400-...", "created_at":"2026-03-19T..."}'
  Good: assert response.body["id"] is not None
        assert "created_at" in response.body
```

### Coverage Requirements

```
MINIMUM COVERAGE:
  Overall:           > 80%
  Domain/Services:   > 90%
  API Routes:        > 85%
  Utilities:         > 95%
  Models/Schemas:    > 70% (mostly structural)

NOT COVERED (acceptable):
  - Framework boilerplate (main.py, config loading)
  - Pure data classes with no logic
  - Third-party library wrappers (thin adapters)
```

## Output Format

After completing TDD for a task:

```json
{
  "task_id": "T-001-02",
  "tdd_cycles": 8,
  "tests_written": 12,
  "tests_passing": 12,
  "coverage": {
    "overall": "91%",
    "domain": "96%",
    "api": "88%"
  },
  "test_breakdown": {
    "unit": 9,
    "integration": 3
  },
  "files": {
    "production": ["domain/services/user_service.py", "api/routes/users.py"],
    "tests": ["tests/unit/test_user_service.py", "tests/integration/test_users_api.py"]
  }
}
```

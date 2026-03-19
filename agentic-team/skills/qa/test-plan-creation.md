# Skill: Test Plan Creation & Execution Strategy

> Load this skill when: A sprint or feature needs a comprehensive test plan
> covering the entire test pyramid before QA execution begins.

## Context

In 100% AI development, you are the LAST LINE OF DEFENSE before code ships.
There is no human tester clicking through the UI. There is no QA lead reviewing
your test coverage. Your test plan must be exhaustive because missed bugs reach
production. If you don't test it, nobody will.

## Test Plan Protocol

### Phase 1: Test Plan Document

For each feature/sprint, produce:

```markdown
# Test Plan: [Feature Name]
## Version: 1.0 | Date: [YYYY-MM-DD] | Sprint: S-[NNN]

### 1. Scope
**In Scope:**
- [What we're testing — list specific user stories and acceptance criteria]

**Out of Scope:**
- [What we're NOT testing in this cycle]

### 2. Test Strategy

| Layer | Coverage Target | Test Count | Tool |
|-------|----------------|------------|------|
| Unit | > 80% | ~50 | pytest / vitest |
| Integration | API endpoints | ~20 | pytest + httpx / supertest |
| Contract | API schema compliance | ~15 | schemathesis / pact |
| E2E | Critical user journeys | ~5 | Playwright |
| Accessibility | WCAG 2.1 AA | per component | axe-core |
| Performance | Response time baselines | ~5 | k6 / locust |
| Security | OWASP Top 10 | ~10 | bandit / npm audit |

### 3. Entry Criteria (before testing begins)
- [ ] All dev tasks marked DONE
- [ ] All unit tests passing
- [ ] Code deployed to test environment
- [ ] API contracts available from Architect
- [ ] Test data seeded

### 4. Exit Criteria (before feature is accepted)
- [ ] All test cases executed
- [ ] 0 critical bugs open
- [ ] 0 high bugs open
- [ ] Medium bugs triaged (fix or defer decision)
- [ ] Coverage targets met
- [ ] Performance baselines established
- [ ] Security scan clean
- [ ] Accessibility audit pass
```

### Phase 2: Test Case Design (BDD Format)

```gherkin
# Group test cases by feature area

@registration @happy-path
Feature: User Registration

  @critical
  Scenario: Successful registration with valid data
    Given I am on the registration page
    And no account exists with email "jane@example.com"
    When I enter email "jane@example.com"
    And I enter name "Jane Doe"
    And I enter password "SecureP@ss123"
    And I click "Create Account"
    Then I should be redirected to the email verification page
    And a user record should exist in the database
    And the user status should be "pending"
    And a verification email should be queued

  @critical
  Scenario: Registration with duplicate email
    Given an account exists with email "jane@example.com"
    When I submit registration with email "jane@example.com"
    Then I should see error "An account with this email already exists"
    And no new account should be created
    And the HTTP status should be 409

  @validation
  Scenario Outline: Registration with invalid data
    When I submit registration with <field> set to <value>
    Then I should see validation error "<error>" for field "<field>"
    And the HTTP status should be 422

    Examples:
      | field    | value              | error                                |
      | email    | ""                 | Email is required                    |
      | email    | "not-an-email"     | Please enter a valid email address   |
      | email    | "a" * 256 + "@x.com" | Email must be less than 255 chars  |
      | name     | ""                 | Name is required                     |
      | name     | "a" * 101         | Name must be less than 100 chars     |
      | password | ""                 | Password is required                 |
      | password | "short"            | Password must be at least 8 chars    |
      | password | "a" * 129         | Password must be less than 128 chars |
      | password | "alllowercase1!"   | Must include uppercase letter        |

  @security
  Scenario: Rate limiting on registration
    Given I have made 10 registration requests in the last minute
    When I submit another registration request
    Then I should receive HTTP 429
    And the response should include Retry-After header
    And no account should be created

  @edge-case
  Scenario: Concurrent duplicate registration
    Given no account exists with email "jane@example.com"
    When two registration requests with email "jane@example.com" arrive simultaneously
    Then exactly one account should be created
    And one request should return 201
    And one request should return 409

  @edge-case
  Scenario: SQL injection attempt in email field
    When I submit registration with email "'; DROP TABLE users; --"
    Then I should see validation error "Please enter a valid email address"
    And the users table should be intact
    And the attempt should be logged

  @edge-case
  Scenario: XSS attempt in name field
    When I submit registration with name "<script>alert('xss')</script>"
    And I view the user profile
    Then the name should be displayed as escaped text
    And no script should execute
```

### Phase 3: Contract Testing

```python
# Verify API responses match Architect's contract EXACTLY

class TestUserApiContract:
    """Tests that API responses match the contract schema."""

    def test_create_user_201_response_matches_contract(self, client):
        response = client.post("/api/v1/users", json={
            "email": "test@example.com",
            "password": "SecureP@ss123",
            "name": "Test User",
        })
        assert response.status_code == 201

        body = response.json()
        # Verify every field from contract exists and has correct type
        assert isinstance(body["id"], str)  # UUID
        assert UUID(body["id"])  # Valid UUID format
        assert body["email"] == "test@example.com"
        assert body["name"] == "Test User"
        assert body["role"] in ("user", "admin")
        assert body["status"] in ("pending", "active", "suspended")
        assert datetime.fromisoformat(body["created_at"])  # Valid ISO 8601

        # Verify NO extra fields (contract is exact)
        expected_fields = {"id", "email", "name", "role", "status", "created_at"}
        assert set(body.keys()) == expected_fields

        # Verify headers
        assert "Location" in response.headers
        assert response.headers["Location"].startswith("/api/v1/users/")

    def test_create_user_409_response_matches_contract(self, client, existing_user):
        response = client.post("/api/v1/users", json={
            "email": existing_user.email,
            "password": "SecureP@ss123",
            "name": "Other User",
        })
        assert response.status_code == 409

        body = response.json()
        assert body["error"] == "email_taken"
        assert isinstance(body["message"], str)
        assert set(body.keys()) == {"error", "message"}

    def test_create_user_422_response_matches_contract(self, client):
        response = client.post("/api/v1/users", json={
            "email": "invalid",
            "password": "x",
            "name": "",
        })
        assert response.status_code == 422

        body = response.json()
        assert body["error"] == "validation_failed"
        assert isinstance(body["details"], list)
        for detail in body["details"]:
            assert "field" in detail
            assert "message" in detail
            assert "code" in detail
```

### Phase 4: Performance Baseline

```python
# k6 performance test template

"""
Performance baseline targets (from NFR):
  - Registration: < 500ms p95
  - Login: < 200ms p95
  - Profile fetch: < 100ms p95
  - User list (paginated): < 300ms p95
"""

# Define thresholds
thresholds = {
    "http_req_duration{endpoint:registration}": ["p(95)<500"],
    "http_req_duration{endpoint:login}": ["p(95)<200"],
    "http_req_duration{endpoint:profile}": ["p(95)<100"],
    "http_req_duration{endpoint:user_list}": ["p(95)<300"],
    "http_req_failed": ["rate<0.01"],  # < 1% error rate
}

# Load pattern
stages = [
    {"duration": "30s", "target": 10},   # Ramp up to 10 users
    {"duration": "1m",  "target": 50},   # Ramp up to 50 users
    {"duration": "2m",  "target": 50},   # Hold at 50 users
    {"duration": "30s", "target": 0},    # Ramp down
]
```

### Phase 5: Test Execution Report

```json
{
  "test_plan": "User Registration",
  "sprint": "S-001",
  "execution_date": "2026-03-19",
  "results": {
    "total_tests": 47,
    "passed": 45,
    "failed": 2,
    "skipped": 0,
    "coverage": "88%"
  },
  "by_layer": {
    "unit": { "total": 25, "passed": 25, "failed": 0 },
    "integration": { "total": 12, "passed": 11, "failed": 1 },
    "contract": { "total": 5, "passed": 4, "failed": 1 },
    "e2e": { "total": 3, "passed": 3, "failed": 0 },
    "performance": { "total": 2, "passed": 2, "failed": 0 }
  },
  "failures": [
    {
      "test": "test_create_user_422_has_code_field",
      "layer": "contract",
      "issue": "422 response missing 'code' field in validation details",
      "severity": "high",
      "bug_id": "BUG-001",
      "assigned_to": "backend_dev"
    }
  ],
  "gate_decision": "FAIL — 1 contract violation must be fixed",
  "performance_baselines": {
    "registration_p95": "312ms (target: 500ms) ✅",
    "login_p95": "89ms (target: 200ms) ✅"
  }
}
```

## Gate Decision Rules

```
PASS:  0 critical + 0 high bugs + all contract tests pass
FAIL:  Any critical OR any high OR contract violation
WARN:  Medium bugs exist → PM decides ship-or-fix
```

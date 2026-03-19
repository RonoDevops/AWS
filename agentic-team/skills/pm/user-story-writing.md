# Skill: User Story Writing

> Load this skill when: Requirements are extracted and need to be converted into
> implementable user stories with acceptance criteria for the dev agents.

## Context

In 100% AI development, user stories are MACHINE-READABLE work instructions.
Every story must be precise enough that an AI agent can implement it WITHOUT
asking a single follow-up question. Ambiguity = bugs.

## Story Writing Protocol

### Step 1: Story Structure

Every story follows this exact template:

```markdown
## US-[NNN]: [Short Title]

**Epic:** [Parent epic or feature name]
**Priority:** [Must | Should | Could | Won't]
**Effort:** [S (< 30 min) | M (1-2 hrs) | L (2-4 hrs) | XL (4-8 hrs)]
**Depends On:** [US-XXX or "None"]
**Assigned To:** [backend_dev | frontend_dev | devops | cloud | security]

### Story
AS A [specific persona — not "user"]
I WANT [specific capability — one thing only]
SO THAT [measurable business value]

### Acceptance Criteria

```gherkin
AC-1: [Title]
  GIVEN [precise precondition with data examples]
  WHEN [specific user/system action]
  THEN [observable, testable outcome]
  AND [additional verifiable outcome]

AC-2: [Title]
  GIVEN [precise precondition]
  WHEN [specific action]
  THEN [outcome]
```

### Technical Notes
- [Implementation hints for the AI agent]
- [Relevant API contracts, DB schemas, or patterns to follow]
- [Links to related stories or architecture decisions]

### Edge Cases
- [Edge case 1: what happens when...]
- [Edge case 2: what happens when...]

### Out of Scope
- [Explicitly what this story does NOT cover]

### Definition of Done
- [ ] All acceptance criteria have passing tests
- [ ] Code passes linting and type checking
- [ ] Security scan clean (no critical/high)
- [ ] API contract matches architect's spec
- [ ] Domain Expert has validated business logic
```

### Step 2: Story Sizing Rules

```
SIZE S (Small — < 30 min AI time):
  - Single function or method change
  - Config update
  - Simple CRUD endpoint (no complex logic)
  - UI text change or style adjustment

SIZE M (Medium — 1-2 hrs AI time):
  - New API endpoint with validation + tests
  - New UI component with states + tests
  - Database migration with data transformation
  - Integration with one external service

SIZE L (Large — 2-4 hrs AI time):
  - New service/module with multiple endpoints
  - Complex business logic with many edge cases
  - Full feature with frontend + backend + tests
  - CI/CD pipeline creation

SIZE XL (Extra Large — 4-8 hrs AI time):
  ⚠️ MUST BE SPLIT into M or L stories
  - If you write an XL story, you haven't decomposed enough
  - Break it into 2-4 smaller stories with clear dependencies
```

### Step 3: Acceptance Criteria Rules

Every AC must be:

```
SPECIFIC   — Uses concrete values, not "appropriate" or "valid"
  BAD:  "THEN the system shows an appropriate error"
  GOOD: "THEN the system returns HTTP 422 with body {"error": "email_taken", "field": "email"}"

MEASURABLE — Has a number or exact match
  BAD:  "THEN the page loads quickly"
  GOOD: "THEN the page loads in < 500ms (p95)"

INDEPENDENT — Each AC tests one thing
  BAD:  "THEN the user is created AND logged in AND redirected AND emailed"
  GOOD: Four separate ACs, one for each outcome

TESTABLE — An AI QA agent can write a test from it directly
  BAD:  "THEN the UX is good"
  GOOD: "THEN the form shows inline validation errors below each invalid field"
```

### Step 4: Story Dependency Mapping

Produce a dependency graph for the sprint:

```
US-001: Create User model + migration          [No deps]
US-002: Create User API endpoints               [Depends: US-001]
US-003: Create User registration UI             [Depends: US-002]
US-004: Add email verification flow             [Depends: US-002]
US-005: Add login/auth flow                     [Depends: US-002]
US-006: Create user profile page                [Depends: US-003, US-005]

Execution order:
  Phase 1 (parallel): US-001
  Phase 2 (parallel): US-002
  Phase 3 (parallel): US-003, US-004, US-005
  Phase 4 (parallel): US-006
```

### Step 5: Story Quality Checklist

Before submitting any story, verify:

```
[ ] Story has exactly ONE capability (not AND/OR combinations)
[ ] "SO THAT" states business value (not technical outcome)
[ ] Every AC uses GIVEN/WHEN/THEN format
[ ] ACs use concrete values (numbers, exact strings, status codes)
[ ] Edge cases are listed (empty input, max values, duplicates, unauthorized)
[ ] Error scenarios have their own ACs
[ ] Size is S, M, or L (XL must be split)
[ ] Dependencies are explicit
[ ] Out of scope is stated
[ ] Technical notes reference architect's contracts
```

## Backlog Prioritization

When multiple stories compete, use this matrix:

```
PRIORITY SCORE = (Business Value × Urgency) / (Effort × Risk)

Business Value: 1-5 (5 = core revenue feature)
Urgency:        1-5 (5 = blocking other work)
Effort:         1-5 (5 = XL, complex)
Risk:           1-5 (5 = unknown tech, external deps)

Score > 3.0  → Must (this sprint)
Score 1.5-3  → Should (this sprint if capacity)
Score 0.5-1.5 → Could (next sprint)
Score < 0.5  → Won't (backlog)
```

## Output

Deliver stories as a structured sprint backlog:

```json
{
  "sprint_id": "S-001",
  "sprint_goal": "Users can register, login, and view their profile",
  "stories": [
    {
      "id": "US-001",
      "title": "Create User model and migration",
      "priority": "Must",
      "effort": "M",
      "assigned_to": "backend_dev",
      "depends_on": [],
      "acceptance_criteria_count": 5
    }
  ],
  "total_effort": "3x M, 2x L, 1x S",
  "execution_phases": 4,
  "estimated_sprint_duration": "~8 hours AI time"
}
```

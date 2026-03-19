# Skill: Sprint Acceptance & Validation

> Load this skill when: A sprint is complete and deliverables need to be validated
> against acceptance criteria before marking the sprint as DONE.

## Context

In 100% AI development, there is no human QA walkthrough. This skill performs
the final product-level acceptance — verifying that what was built matches what
was asked for, not just that tests pass. Tests can pass while the feature is wrong.

## Acceptance Protocol

### Phase 1: Deliverable Inventory

Collect outputs from ALL agents and verify completeness:

```
SPRINT: [Sprint ID]
GOAL: [Sprint goal statement]

STORY CHECKLIST:
| Story ID | Title | Status | Tests | Code Review | Security | Accepted |
|----------|-------|--------|-------|-------------|----------|----------|
| US-001   | ...   | DONE   | 12/12 | APPROVED    | CLEAN    | [ ]      |
| US-002   | ...   | DONE   | 8/8   | APPROVED    | CLEAN    | [ ]      |
| US-003   | ...   | DONE   | 15/15 | 1 ISSUE     | CLEAN    | [ ]      |

MISSING DELIVERABLES:
- [ ] Any story not marked DONE? → Sprint incomplete
- [ ] Any tests failing? → Cannot accept
- [ ] Any code review issues unresolved? → Cannot accept
- [ ] Any critical security findings? → Cannot accept
```

### Phase 2: Acceptance Criteria Walkthrough

For EACH story, verify EACH acceptance criterion:

```
US-001: Create User Registration API
  AC-1: Valid registration → ✅ Test exists, test passes, behavior correct
  AC-2: Duplicate email    → ✅ Returns 409, message matches spec
  AC-3: Weak password      → ✅ Returns 422, validation rules enforced
  AC-4: Rate limiting      → ⚠️ Test passes but limit is 1000/min (spec says 100/min)
  AC-5: Email confirmation → ✅ Email queued, token generated, 24hr expiry

  VERDICT: CONDITIONAL ACCEPT — AC-4 needs rate limit adjustment
```

### Phase 3: Integration Verification

Verify that components work TOGETHER, not just individually:

```
INTEGRATION CHECKS:
[ ] Frontend calls correct backend endpoints (URL, method, headers)
[ ] API responses match frontend's expected schema
[ ] Error states propagate correctly (backend error → frontend error display)
[ ] Auth flow works end-to-end (register → verify → login → authenticated request)
[ ] Data persists correctly (create → read back → matches)
[ ] Concurrent operations don't corrupt state
```

### Phase 4: Sprint Goal Validation

Answer the fundamental question:

```
SPRINT GOAL: "[The sprint goal statement]"

GOAL MET?
  YES — All stories accepted, integration verified, goal achieved
  PARTIAL — [X of Y] stories accepted, core goal met but gaps remain
  NO — Critical stories failed acceptance, goal not achieved

GAPS (if any):
  - [Gap 1: What's missing and why]
  - [Gap 2: What's missing and why]

CARRY-OVER:
  - [Story/task to carry to next sprint]
```

### Phase 5: Acceptance Report

```json
{
  "sprint_id": "S-001",
  "sprint_goal": "Users can register, login, and view profile",
  "verdict": "ACCEPTED" | "CONDITIONAL" | "REJECTED",
  "stories_accepted": 5,
  "stories_rejected": 1,
  "stories_conditional": 1,
  "conditions": [
    {
      "story": "US-004",
      "issue": "Rate limit set to 1000/min instead of 100/min",
      "severity": "medium",
      "action": "Fix in next sprint or hotfix"
    }
  ],
  "integration_status": "PASS",
  "security_status": "CLEAN",
  "performance_status": "WITHIN_TARGETS",
  "next_sprint_recommendations": [
    "Carry over US-006 (blocked by external API)",
    "Add monitoring for registration flow",
    "Address 2 medium security findings"
  ]
}
```

## Rejection Criteria (Automatic REJECT)

Any of these = sprint NOT accepted:
1. Any story has failing tests
2. Critical security vulnerability unresolved
3. API contracts don't match architect's spec
4. Core user flow broken end-to-end
5. Data loss or corruption scenario exists
6. Performance > 3x target thresholds

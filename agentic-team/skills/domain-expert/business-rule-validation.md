# Skill: Business Rule Validation & Edge Case Discovery

> Load this skill when: Code has been written implementing business logic and
> needs to be validated against the domain model, or when edge cases need
> to be discovered for a new feature.

## Context

In 100% AI development, business rule bugs are the most dangerous. They don't
crash the app — they silently produce WRONG RESULTS. A calculation off by one
cent, a state transition that skips validation, a permission check that's too
loose. This skill catches them.

## Business Rule Validation Protocol

### Phase 1: Rule Extraction Audit

For every piece of business logic code, verify:

```
CHECKLIST FOR EACH INVARIANT IN THE DOMAIN MODEL:

[ ] INV is enforced in domain layer (not just UI or API validation)
[ ] INV is enforced at the aggregate root level (not scattered)
[ ] INV is tested with a dedicated unit test
[ ] INV violation produces a specific, descriptive error
[ ] INV cannot be bypassed by any code path (direct DB write, admin API, etc.)

EXAMPLE:
  INV-1: "Order total must equal sum of line totals"

  CHECK: Is this computed or stored?
    If stored → is it recalculated when lines change? What about DELETE?
    If computed → is it computed at read time? What about reports/exports?

  CHECK: What happens when:
    - A line is added? → Total must update
    - A line is removed? → Total must update
    - A line quantity changes? → Total must update
    - A line price changes? → Total must update
    - Currency conversion? → Rounding errors?
    - Concurrent modifications? → Race condition on total?
```

### Phase 2: State Machine Validation

For every entity with a status/state field:

```
STATE MACHINE AUDIT:

  Define the EXPECTED transitions:
    draft → placed → confirmed → shipped → delivered
                 ↘ cancelled   ↘ cancelled   ↘ returned

  Then verify in code:
    [ ] Every transition is explicitly defined (whitelist, not blacklist)
    [ ] Invalid transitions throw specific errors
    [ ] Side effects happen on transition (not on status check)
    [ ] Timestamps are set on transition (shipped_at set when → shipped)
    [ ] Events are emitted on transition (OrderShipped event)
    [ ] No "back" transitions unless explicitly designed (delivered → returned: OK)
    [ ] Terminal states cannot transition (cancelled → anything: MUST FAIL)

  DANGEROUS PATTERN — Direct status update:
    BAD:  order.status = "shipped"  (bypasses all guards)
    GOOD: order.ship(tracking_number)  (method enforces rules)
```

### Phase 3: Edge Case Discovery Matrix

For every business operation, systematically explore:

```
EDGE CASE MATRIX:

| Category | Question | Example |
|----------|----------|---------|
| ZERO | What if the value is 0? | Order with $0.00 total — allowed? |
| ONE | What if there's exactly 1? | Order with 1 line item — special handling? |
| MANY | What if there are many? | Order with 50 line items (max) |
| BOUNDARY | What about the exact boundary? | Order with 51 line items (max + 1) |
| EMPTY | What if the collection is empty? | Order with no line items |
| NULL | What if the value is missing? | Order without shipping address |
| DUPLICATE | What if it's done twice? | Double-click "Place Order" |
| CONCURRENT | What if two happen at once? | Two users edit same order |
| TIMING | What about time-sensitive logic? | Coupon expired 1 second ago |
| CURRENCY | What about money precision? | $1.005 — round up or down? |
| UNICODE | What about special characters? | Name: "José O'Brien-Smith III" |
| OVERFLOW | What about very large values? | Quantity: 999,999,999 |
| NEGATIVE | What about negative values? | Quantity: -1 (return vs purchase?) |
| TIMEZONE | What about time zones? | Order placed at 11:59 PM PST — which date? |
| PERMISSION | Who can do this operation? | Can a user cancel someone else's order? |
| IDEMPOTENCY | What if retried? | Payment webhook received twice |
| ORDERING | Does sequence matter? | Ship before confirm? |
| PARTIAL | What about partial success? | 3 of 5 items in stock |
```

### Phase 4: Business Logic Code Review

```
REVIEW CHECKLIST:

CALCULATIONS:
  [ ] Money uses Decimal/BigDecimal, NEVER float
  [ ] Rounding strategy is explicit (HALF_UP, BANKER'S, etc.)
  [ ] Tax calculation matches jurisdiction rules
  [ ] Discount stacking rules are correct (percentage then fixed? Or fixed then percentage?)
  [ ] Currency conversion uses mid-market rate with explicit timestamp

COMPARISONS:
  [ ] Date comparisons use consistent timezone (UTC everywhere, convert at UI)
  [ ] String comparisons are case-insensitive where appropriate (email)
  [ ] Enum comparisons use the enum type, not string matching
  [ ] Money comparisons use the same currency

DATA INTEGRITY:
  [ ] Foreign keys exist for all relationships
  [ ] Cascading deletes are intentional (not accidental data loss)
  [ ] Soft delete vs hard delete is consistent
  [ ] Audit trail captures who changed what when
  [ ] Optimistic locking prevents lost updates
```

### Phase 5: Edge Case Test Specification

For every discovered edge case, produce a test spec:

```gherkin
# Edge Case: Double order placement (idempotency)
Scenario: User clicks "Place Order" twice rapidly
  Given a user has a cart with items
  When the user submits the order twice within 1 second
  Then only one order should be created
  And the second request should return the existing order
  And payment should be charged only once

# Edge Case: Currency precision
Scenario: Line item total has sub-cent precision
  Given an order with quantity 3 and unit price $1.33
  When the line total is calculated
  Then the result should be $3.99 (not $3.990000000001)
  And the order total should use HALF_UP rounding

# Edge Case: State transition guard
Scenario: Attempting to ship a cancelled order
  Given an order with status "cancelled"
  When the admin attempts to ship the order
  Then the system should reject with error "Cannot ship cancelled order"
  And the order status should remain "cancelled"
```

## Output Format

```json
{
  "feature": "Order Management",
  "invariants_audited": 8,
  "invariants_passing": 7,
  "invariants_failing": 1,
  "failures": [
    {
      "invariant": "INV-1: Total must match sum of lines",
      "issue": "Total not recalculated when line is deleted",
      "severity": "critical",
      "assigned_to": "backend_dev"
    }
  ],
  "edge_cases_discovered": 14,
  "edge_cases_with_tests": 10,
  "edge_cases_needing_tests": 4,
  "state_machine_valid": true,
  "ubiquitous_language_violations": 2
}
```

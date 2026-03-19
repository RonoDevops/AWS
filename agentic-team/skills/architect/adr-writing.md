# Skill: Architecture Decision Records (ADRs)

> Load this skill when: A significant technical decision needs to be made and
> documented — technology choice, pattern selection, trade-off resolution.

## Context

In 100% AI development, ADRs are the institutional memory. When an AI agent asks
"why did we choose PostgreSQL over DynamoDB?", the ADR answers. Without ADRs,
agents will make contradictory decisions or re-debate settled questions.

## When to Write an ADR

```
ALWAYS write an ADR when:
  ✓ Choosing a database, framework, language, or major library
  ✓ Selecting an architecture pattern (monolith vs microservices, REST vs gRPC)
  ✓ Making a security decision (auth strategy, encryption approach)
  ✓ Defining a data flow pattern (sync vs async, push vs pull)
  ✓ Setting a team standard (code style, branching strategy, testing strategy)
  ✓ Accepting technical debt (with explicit payoff plan)

NEVER write an ADR for:
  ✗ Trivial decisions (variable naming, formatting)
  ✗ Temporary experiments (spikes that will be thrown away)
  ✗ Decisions already mandated by constraints
```

## ADR Template

```markdown
# ADR-[NNN]: [Decision Title]

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-XXX]

## Date
[YYYY-MM-DD]

## Context
[What is the technical problem or force that drives this decision?
What constraints exist? What are we trying to optimize for?
Include specific numbers: request volume, data size, team size, timeline.]

## Options Considered

### Option A: [Name]
**Description:** [How it works]
**Pros:**
- [Advantage 1 with specific evidence]
- [Advantage 2]
**Cons:**
- [Disadvantage 1 with impact assessment]
- [Disadvantage 2]
**Effort:** [S | M | L | XL]
**Risk:** [Low | Medium | High] — [why]

### Option B: [Name]
**Description:** [How it works]
**Pros:** ...
**Cons:** ...
**Effort:** ...
**Risk:** ...

### Option C: [Name] (if applicable)
...

## Decision Matrix

| Criterion (weight) | Option A | Option B | Option C |
|---------------------|----------|----------|----------|
| Performance (30%)   | ★★★★☆   | ★★★☆☆   | ★★★★★   |
| Simplicity (25%)    | ★★★★★   | ★★☆☆☆   | ★★★☆☆   |
| Scalability (20%)   | ★★★☆☆   | ★★★★★   | ★★★★☆   |
| Cost (15%)          | ★★★★★   | ★★☆☆☆   | ★★★☆☆   |
| Team familiarity(10%)| ★★★★☆  | ★★★☆☆   | ★★☆☆☆   |
| **Weighted Score**  | **4.05** | **3.15** | **3.60** |

## Decision
We choose **Option [X]** because [primary rationale].

[2-3 sentences explaining the WHY — not just what, but why this
trade-off is right for our specific context.]

## Consequences

### Positive
- [What becomes easier or better]
- [What risk is mitigated]

### Negative
- [What trade-off we accept]
- [What becomes harder]

### Neutral
- [What changes but isn't clearly better or worse]

## Follow-up Actions
- [ ] [Action 1: e.g., "Configure connection pooling for PostgreSQL"]
- [ ] [Action 2: e.g., "Set up monitoring for query performance"]
- [ ] [Revisit trigger: e.g., "If requests > 5000/s, reconsider DynamoDB"]

## References
- [Link to relevant documentation, benchmarks, or prior decisions]
```

## ADR Quality Rules

```
RULE 1: QUANTIFY EVERYTHING
  Bad:  "Option A is faster"
  Good: "Option A handles 10,000 req/s vs Option B's 2,000 req/s"

RULE 2: STATE THE TRADE-OFF EXPLICITLY
  Bad:  "We chose PostgreSQL"
  Good: "We chose PostgreSQL, accepting that horizontal scaling requires
         read replicas or sharding, because our current data model is
         heavily relational and 500GB fits comfortably in a single instance"

RULE 3: INCLUDE REVERSAL CONDITIONS
  Bad:  (no mention of when to revisit)
  Good: "Revisit this decision if: data exceeds 1TB, write throughput > 5000/s,
         or we need multi-region active-active replication"

RULE 4: ONE DECISION PER ADR
  Bad:  "ADR-005: Database and caching strategy"
  Good: "ADR-005: Database selection" + "ADR-006: Caching strategy"

RULE 5: ADRs ARE IMMUTABLE
  Never edit an accepted ADR. If the decision changes, write a NEW ADR
  that references "Supersedes ADR-XXX" and mark the old one as deprecated.
```

## ADR Registry

Maintain a running index:

```markdown
| ADR | Title | Status | Date |
|-----|-------|--------|------|
| 001 | Database selection: PostgreSQL | Accepted | 2026-03-19 |
| 002 | Auth strategy: JWT + RBAC | Accepted | 2026-03-19 |
| 003 | API style: REST over gRPC | Accepted | 2026-03-19 |
| 004 | Monolith vs microservices | Accepted | 2026-03-19 |
| 005 | Frontend framework: Next.js 14 | Accepted | 2026-03-19 |
```

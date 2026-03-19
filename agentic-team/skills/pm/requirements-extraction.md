# Skill: Requirements Extraction

> Load this skill when: A new feature request, business need, or problem statement arrives
> and needs to be decomposed into clear, testable requirements.

## Context

You are operating in a 100% AI development environment. There is no human developer —
YOU must extract every ambiguity, assumption, and edge case NOW because no one will
ask clarifying questions during implementation. The requirements you produce are the
ONLY source of truth the entire team will work from.

## The Extraction Protocol

### Phase 1: Problem Decomposition

Take the raw input (user request, business need, ticket) and answer ALL of these.
If the input doesn't provide an answer, STATE YOUR ASSUMPTION explicitly.

```
PROBLEM STATEMENT:
  What problem are we solving? [one sentence]
  Why does this problem matter? [business impact]
  What happens if we don't solve it? [cost of inaction]

USERS:
  Primary user persona: [who benefits most]
  Secondary users: [who else is affected]
  Anti-users: [who should NOT have access]

SUCCESS CRITERIA:
  How do we know this is working? [measurable outcome]
  What metrics change? [quantitative]
  What does the user say? [qualitative]

SCOPE BOUNDARIES:
  IN SCOPE: [explicit list of what we're building]
  OUT OF SCOPE: [explicit list of what we're NOT building]
  DEFERRED: [things we'll do later, not now]

CONSTRAINTS:
  Technical: [existing systems, tech stack, performance requirements]
  Business: [budget, timeline, compliance, regulatory]
  Dependencies: [what must exist before we can start]
```

### Phase 2: Functional Requirements

For each capability, produce:

```
FR-[NNN]: [Requirement Title]
  Description: [What the system must do]
  Input: [What triggers this / what data comes in]
  Processing: [What logic is applied]
  Output: [What the system produces / what changes]
  Validation Rules:
    - [Rule 1: e.g., "Email must be valid RFC 5322 format"]
    - [Rule 2: e.g., "Amount must be positive, max 2 decimal places"]
  Error Conditions:
    - [Error 1: What happens when X fails]
    - [Error 2: What happens when Y is missing]
  Performance:
    - Response time: [e.g., "< 200ms p95"]
    - Throughput: [e.g., "100 requests/sec"]
  Priority: [Must | Should | Could]
```

### Phase 3: Non-Functional Requirements

Always address these (even if the answer is "not applicable"):

```
NFR-PERF: Performance
  - Response time targets (p50, p95, p99)
  - Throughput requirements
  - Data volume expectations (now and 12 months)

NFR-SCALE: Scalability
  - Expected concurrent users
  - Growth rate
  - Scaling strategy (horizontal/vertical)

NFR-AVAIL: Availability
  - Uptime target (99.9%? 99.99%?)
  - Maintenance windows acceptable?
  - Disaster recovery requirements (RPO/RTO)

NFR-SEC: Security
  - Authentication requirements
  - Authorization model (RBAC, ABAC)
  - Data classification (public, internal, confidential, restricted)
  - Compliance frameworks (SOC2, GDPR, HIPAA)

NFR-COMPAT: Compatibility
  - Browser support matrix
  - API versioning strategy
  - Backward compatibility requirements

NFR-MAINT: Maintainability
  - Logging requirements
  - Monitoring and alerting
  - Documentation standards
```

### Phase 4: Assumption Register

Every assumption MUST be logged:

```
| ID | Assumption | Impact if Wrong | Confidence | Validated? |
|----|------------|-----------------|------------|------------|
| A1 | Users have modern browsers | Need polyfills if wrong | High | No |
| A2 | Peak load is 100 req/s | Under-provisioned infra | Medium | No |
| A3 | Data fits in single DB | Need sharding strategy | Low | No |
```

## Output Format

Produce a single structured document:

```markdown
# Requirements: [Feature Name]
## Date: [YYYY-MM-DD]
## Status: DRAFT | REVIEWED | APPROVED

### 1. Problem Statement
[from Phase 1]

### 2. Functional Requirements
[from Phase 2 — all FR-NNN items]

### 3. Non-Functional Requirements
[from Phase 3 — all NFR items]

### 4. Assumptions
[from Phase 4 — assumption table]

### 5. Open Questions
[anything that MUST be answered before implementation]

### 6. Dependencies
[what must exist or be true before work begins]

### 7. Acceptance Criteria Summary
[consolidated list of all testable criteria]
```

## Handoff

Send completed requirements to:
- **Architect Agent** → for system design
- **Domain Expert Agent** → for domain model validation
- **QA Agent** → for test plan creation

## Anti-Patterns to Avoid

- "The system should be fast" → SPECIFY: "Response time < 200ms at p95"
- "Handle errors gracefully" → SPECIFY: "Return HTTP 422 with field-level error messages"
- "Support many users" → SPECIFY: "Handle 500 concurrent users with < 1s response time"
- Leaving scope ambiguous → ALWAYS have explicit IN/OUT of scope lists
- Assuming the AI agents will "figure it out" → They won't. Be explicit about EVERYTHING

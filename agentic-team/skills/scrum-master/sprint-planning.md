# Skill: Sprint Planning & Task Decomposition

> Load this skill when: User stories are ready from PM and need to be broken into
> executable tasks, assigned to agents, ordered by dependency, and scheduled.

## Context

In 100% AI development, sprint planning is graph construction. You are building a
DAG (Directed Acyclic Graph) of tasks that AI agents will execute. Every task must
be atomic, assigned, and dependency-aware so the LangGraph orchestrator can
parallelize maximum work.

## Sprint Planning Protocol

### Phase 1: Story → Task Decomposition

For each user story, produce tasks using this template:

```
STORY: US-[NNN] — [Title]

TASKS:
  T-[NNN]-01: [Verb] [Object] [Context]
    Agent: [backend_dev | frontend_dev | uiux | devops | cloud | security]
    Depends: [T-XXX-YY or "None"]
    Effort: [S | M | L]
    Inputs: [What this agent needs to start — contracts, specs, schemas]
    Outputs: [What this agent produces — files, configs, test results]
    Done When: [Specific, testable completion condition]

  T-[NNN]-02: ...
```

### Task Decomposition Rules

```
RULE 1: ONE AGENT PER TASK
  Bad:  "Build user registration" (needs backend + frontend + DB)
  Good: T-001-01: "Create User table migration" (backend_dev)
        T-001-02: "Create POST /users endpoint" (backend_dev)
        T-001-03: "Create RegistrationForm component" (frontend_dev)

RULE 2: VERB-FIRST NAMING
  Template: [Create|Update|Add|Remove|Configure|Test|Review|Deploy] [thing]
  Bad:  "User authentication"
  Good: "Create JWT authentication middleware"

RULE 3: EXPLICIT INPUTS/OUTPUTS
  Every task consumes something and produces something.
  Bad:  Inputs: "see architecture doc"
  Good: Inputs: "API contract from ADR-005, User schema from domain model v2"

RULE 4: MAX 2 HOURS AI TIME PER TASK
  If a task takes longer, split it further.

RULE 5: TESTS ARE SEPARATE TASKS (or embedded in implementation)
  Option A: "Create User endpoint + unit tests" (TDD — tests are part of implementation)
  Option B: "Write integration tests for User flow" (separate QA task)
```

### Phase 2: Dependency Graph

Build the execution DAG:

```
SPRINT S-001 EXECUTION GRAPH:

Phase 1 — Foundation (no dependencies):
  ├── T-001-01: Create User DB migration          [backend_dev]
  ├── T-002-01: Design registration user flow      [uiux]
  └── T-003-01: Create Terraform module for RDS    [cloud]

Phase 2 — Core APIs (depends on Phase 1):
  ├── T-001-02: Create POST /users endpoint        [backend_dev] → needs T-001-01
  ├── T-001-03: Create GET /users/:id endpoint     [backend_dev] → needs T-001-01
  └── T-003-02: Configure CI/CD pipeline           [devops]      → needs T-003-01

Phase 3 — Frontend + Integration (depends on Phase 2):
  ├── T-002-02: Create RegistrationForm component  [frontend_dev] → needs T-001-02, T-002-01
  ├── T-002-03: Create LoginForm component         [frontend_dev] → needs T-001-02, T-002-01
  └── T-004-01: Create auth integration tests      [qa]           → needs T-001-02

Phase 4 — Verification (depends on Phase 3):
  ├── T-005-01: Run security scan                  [security]     → needs ALL Phase 3
  ├── T-005-02: Run E2E acceptance tests           [qa]           → needs ALL Phase 3
  └── T-005-03: Performance baseline test          [qa]           → needs ALL Phase 3

CRITICAL PATH: T-001-01 → T-001-02 → T-002-02 → T-005-02
TOTAL PHASES: 4
MAX PARALLELISM: 3 agents in Phase 1, 3 in Phase 2, 3 in Phase 3, 3 in Phase 4
```

### Phase 3: Sprint Capacity & Assignment

```
AGENT CAPACITY (per sprint):
  backend_dev:  8 tasks (M average)
  frontend_dev: 6 tasks (M average)
  uiux:         4 tasks (design-heavy)
  qa:           6 tasks (test-heavy)
  devops:       3 tasks (infra-heavy)
  cloud:        3 tasks (provisioning)
  security:     4 tasks (scan + review)

ASSIGNMENT RULES:
  - Never assign > 2 tasks to same agent in same phase (bottleneck risk)
  - Security always runs AFTER dev tasks (needs code to scan)
  - QA runs integration tests AFTER all component tasks done
  - DevOps runs in parallel with dev (pipeline doesn't need app code)
```

### Phase 4: Sprint Board Initialization

```json
{
  "sprint_id": "S-001",
  "sprint_goal": "Users can register, login, and view profile",
  "start_date": "2026-03-19",
  "duration": "~12 hours AI execution time",
  "phases": 4,
  "total_tasks": 15,
  "task_breakdown": {
    "backend_dev": 5,
    "frontend_dev": 3,
    "uiux": 2,
    "qa": 3,
    "devops": 1,
    "cloud": 1,
    "security": 1
  },
  "board": {
    "BACKLOG": [],
    "TODO": ["T-001-01", "T-002-01", "T-003-01"],
    "IN_PROGRESS": [],
    "IN_REVIEW": [],
    "DONE": [],
    "ACCEPTED": []
  }
}
```

## Handoff

Deliver to each agent:
1. Their assigned tasks with full context
2. Input artifacts they need (contracts, schemas, design specs)
3. The dependency graph so they know what to wait for
4. Definition of done for each task

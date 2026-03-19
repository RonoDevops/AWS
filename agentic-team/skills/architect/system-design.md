# Skill: System Design & Architecture

> Load this skill when: A new feature or system needs architectural design before
> any code is written. Produces the blueprint that ALL agents build from.

## Context

In 100% AI development, the architecture IS the contract. If the design is wrong,
every downstream agent builds on a broken foundation. You must think through
scalability, fault tolerance, data flow, and integration BEFORE any agent writes code.
The AI agents cannot "ask the architect later" — your design must be complete.

## System Design Protocol

### Phase 1: Architecture Drivers

Before drawing ANY diagram, capture:

```
FUNCTIONAL DRIVERS:
  What are the core capabilities? [list top 5]
  What data flows through the system? [input → transform → output]
  What external systems do we integrate with? [APIs, databases, services]
  What are the critical user journeys? [most important paths]

QUALITY ATTRIBUTE REQUIREMENTS:
  Performance:    [response time, throughput, latency targets]
  Scalability:    [concurrent users now, in 6 months, in 2 years]
  Availability:   [uptime %, acceptable downtime per month]
  Security:       [auth model, data classification, compliance]
  Maintainability: [deployment frequency, team structure, testability]

CONSTRAINTS:
  Technical:  [existing systems, mandated tech, legacy integration]
  Business:   [budget, timeline, team skills]
  Regulatory: [data residency, audit trails, encryption requirements]
```

### Phase 2: C4 Architecture Model

Produce designs at 4 levels of detail:

```
LEVEL 1 — SYSTEM CONTEXT:
  What: How this system relates to users and external systems
  Format: System context diagram showing:
    - The system (single box)
    - Users/personas (stick figures)
    - External systems (boxes)
    - Relationships (labeled arrows)

LEVEL 2 — CONTAINER DIAGRAM:
  What: High-level technology choices and deployment units
  Format:
    ┌─────────────────────────────────────────────┐
    │                  SYSTEM                       │
    │  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
    │  │ Web App  │  │ API      │  │ Worker   │  │
    │  │ (React)  │→ │ (FastAPI)│→ │ (Celery) │  │
    │  └──────────┘  └─────┬────┘  └──────────┘  │
    │                      │                       │
    │                ┌─────▼────┐                  │
    │                │ Database │                  │
    │                │(Postgres)│                  │
    │                └──────────┘                  │
    └─────────────────────────────────────────────┘

LEVEL 3 — COMPONENT DIAGRAM (per container):
  What: Internal structure of each container
  Format: Classes/modules with relationships

LEVEL 4 — CODE (delegated to dev agents):
  What: Actual implementation
  Provided by: Backend Dev, Frontend Dev agents
```

### Phase 3: API Contract Design

For every service boundary, produce:

```yaml
# OpenAPI-style contract
service: user-service
base_path: /api/v1

endpoints:
  - path: /users
    method: POST
    description: Create new user account
    request:
      content_type: application/json
      body:
        email: { type: string, format: email, required: true }
        password: { type: string, min_length: 8, required: true }
        name: { type: string, max_length: 100, required: true }
    responses:
      201:
        body: { id: uuid, email: string, name: string, created_at: datetime }
      409:
        body: { error: "email_taken", message: string }
      422:
        body: { errors: [{ field: string, message: string }] }
    rate_limit: 10/minute
    auth: none (public endpoint)

  - path: /users/{id}
    method: GET
    description: Get user by ID
    auth: bearer_token (must be same user or admin)
    responses:
      200:
        body: { id: uuid, email: string, name: string, created_at: datetime }
      401:
        body: { error: "unauthorized" }
      403:
        body: { error: "forbidden" }
      404:
        body: { error: "not_found" }
```

### Phase 4: Data Model

```
ENTITIES:
  User:
    id:         UUID (PK, auto-generated)
    email:      VARCHAR(255) UNIQUE NOT NULL
    password:   VARCHAR(255) NOT NULL (bcrypt hashed)
    name:       VARCHAR(100) NOT NULL
    role:       ENUM('user', 'admin') DEFAULT 'user'
    status:     ENUM('pending', 'active', 'suspended') DEFAULT 'pending'
    created_at: TIMESTAMP DEFAULT NOW()
    updated_at: TIMESTAMP DEFAULT NOW() ON UPDATE

  INDEXES:
    idx_user_email: UNIQUE(email)
    idx_user_status: (status) — for admin queries

  RELATIONSHIPS:
    User 1:N Orders
    User 1:N Sessions

  MIGRATIONS:
    V001: Create users table
    V002: Add status column with default
```

### Phase 5: Architecture Decision Record (ADR)

```markdown
## ADR-001: [Decision Title]

### Status: Proposed → Accepted

### Context
[Problem forcing this decision]

### Options Considered
| Option | Pros | Cons | Effort |
|--------|------|------|--------|
| A: Monolith (FastAPI) | Simple, fast to build, easy to test | Scaling limits at ~1000 req/s | S |
| B: Microservices | Independent scaling, team autonomy | Complexity, networking, observability | XL |
| C: Modular monolith | Monolith speed + service boundaries | Needs discipline to maintain boundaries | M |

### Decision
Option C: Modular monolith. We get the deployment simplicity of a monolith
with the architectural boundaries of services. We can extract to microservices
later IF we need independent scaling.

### Consequences
+ Fast initial development (single deployment)
+ Clear module boundaries (enforced by dependency rules)
+ Easy testing (in-process, no network calls)
- Must enforce boundaries manually (no network isolation)
- Must extract later if modules need independent scaling
```

## Design Output Format

```json
{
  "system_name": "Feature X",
  "architecture_pattern": "modular_monolith",
  "adrs": ["ADR-001", "ADR-002"],
  "containers": [
    {"name": "web-app", "tech": "Next.js 14", "type": "frontend"},
    {"name": "api-server", "tech": "FastAPI", "type": "backend"},
    {"name": "database", "tech": "PostgreSQL 16", "type": "datastore"},
    {"name": "cache", "tech": "Redis 7", "type": "cache"}
  ],
  "api_contracts": "docs/api/openapi.yaml",
  "data_model": "docs/data/erd.md",
  "security_model": "JWT + RBAC, see ADR-002",
  "deployment": "ECS Fargate, see cloud agent tasks"
}
```

## Handoff

Deliver to:
- **Backend Dev** → API contracts, data model, module structure
- **Frontend Dev** → API contracts, auth flow, data schemas
- **DevOps** → Container architecture, deployment model
- **Cloud** → Infrastructure requirements, scaling targets
- **Security** → Attack surfaces, auth model, data classification
- **QA** → Contract test specs, integration test boundaries

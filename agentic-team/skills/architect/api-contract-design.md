# Skill: API Contract Design (Contract-First Development)

> Load this skill when: Services or components need to communicate and the
> interface must be defined BEFORE implementation begins.

## Context

In 100% AI development, contracts are the handshake between agents. The Backend Dev
agent and Frontend Dev agent NEVER talk to each other — they both read the contract.
If the contract is ambiguous, they build incompatible code. Contracts must be
machine-precise and cover every edge case.

## Contract-First Protocol

### Principle: Design the API BEFORE Writing Any Code

```
Traditional:  Write code → Extract API → Document it
Contract-First: Design API → Both sides implement against it → Guaranteed compatibility

WHY: In AI development, agents work in PARALLEL. Backend and Frontend
      start at the same time. Without a contract, they'll build
      incompatible interfaces.
```

### Phase 1: Endpoint Inventory

List every endpoint the feature needs:

```
FEATURE: User Management

ENDPOINTS:
| Method | Path              | Purpose                    | Auth Required |
|--------|-------------------|----------------------------|---------------|
| POST   | /api/v1/users     | Create user account        | No            |
| GET    | /api/v1/users/:id | Get user profile           | Yes (self/admin) |
| PATCH  | /api/v1/users/:id | Update user profile        | Yes (self)    |
| DELETE | /api/v1/users/:id | Deactivate user account    | Yes (admin)   |
| POST   | /api/v1/auth/login | Authenticate user          | No            |
| POST   | /api/v1/auth/refresh | Refresh access token     | Yes (refresh) |
| GET    | /api/v1/users     | List users (paginated)     | Yes (admin)   |
```

### Phase 2: Full Contract Per Endpoint

For EACH endpoint, specify:

```yaml
endpoint: POST /api/v1/users
description: Create a new user account

request:
  headers:
    Content-Type: application/json
    X-Request-ID: { type: uuid, required: false, description: "Idempotency key" }
  body:
    type: object
    required: [email, password, name]
    properties:
      email:
        type: string
        format: email
        max_length: 255
        example: "jane@example.com"
        validation: "RFC 5322 compliant, case-insensitive uniqueness"
      password:
        type: string
        min_length: 8
        max_length: 128
        example: "SecureP@ss123"
        validation: "At least 1 uppercase, 1 lowercase, 1 digit, 1 special char"
      name:
        type: string
        min_length: 1
        max_length: 100
        example: "Jane Doe"
        validation: "Trimmed, no leading/trailing whitespace"

responses:
  201_created:
    description: User successfully created
    headers:
      Location: "/api/v1/users/{id}"
    body:
      type: object
      properties:
        id: { type: uuid, example: "550e8400-e29b-41d4-a716-446655440000" }
        email: { type: string, example: "jane@example.com" }
        name: { type: string, example: "Jane Doe" }
        role: { type: string, enum: [user, admin], example: "user" }
        status: { type: string, enum: [pending, active], example: "pending" }
        created_at: { type: datetime, format: "ISO 8601", example: "2026-03-19T10:30:00Z" }

  409_conflict:
    description: Email already registered
    body:
      type: object
      properties:
        error: { type: string, value: "email_taken" }
        message: { type: string, example: "An account with this email already exists" }

  422_validation_error:
    description: Request validation failed
    body:
      type: object
      properties:
        error: { type: string, value: "validation_failed" }
        details:
          type: array
          items:
            type: object
            properties:
              field: { type: string, example: "password" }
              message: { type: string, example: "Must be at least 8 characters" }
              code: { type: string, example: "min_length" }

  429_rate_limited:
    description: Too many requests
    headers:
      Retry-After: { type: integer, description: "Seconds to wait" }
    body:
      type: object
      properties:
        error: { type: string, value: "rate_limited" }
        retry_after: { type: integer, example: 60 }

rate_limit: "10 requests per minute per IP"
idempotency: "If X-Request-ID header is present, deduplicate within 24 hours"
```

### Phase 3: Pagination Contract (for list endpoints)

```yaml
pagination_standard:
  query_params:
    page: { type: integer, default: 1, min: 1 }
    per_page: { type: integer, default: 20, min: 1, max: 100 }
    sort_by: { type: string, allowed: [created_at, name, email], default: created_at }
    sort_order: { type: string, allowed: [asc, desc], default: desc }

  response_envelope:
    data: [ ...items... ]
    pagination:
      page: 1
      per_page: 20
      total_items: 156
      total_pages: 8
      has_next: true
      has_prev: false
```

### Phase 4: Error Contract (global)

```yaml
error_format:
  description: All errors follow this structure
  body:
    error: { type: string, description: "Machine-readable error code" }
    message: { type: string, description: "Human-readable description" }
    details: { type: array, description: "Field-level errors (optional)" }
    request_id: { type: uuid, description: "Correlation ID for debugging" }

  standard_errors:
    400: { error: "bad_request", when: "Malformed JSON or invalid content type" }
    401: { error: "unauthorized", when: "Missing or expired auth token" }
    403: { error: "forbidden", when: "Valid token but insufficient permissions" }
    404: { error: "not_found", when: "Resource does not exist" }
    409: { error: "conflict", when: "Resource state conflict (duplicate, etc.)" }
    422: { error: "validation_failed", when: "Valid JSON but business rule violation" }
    429: { error: "rate_limited", when: "Too many requests" }
    500: { error: "internal_error", when: "Server bug (include request_id for debugging)" }
```

### Phase 5: Event Contract (for async communication)

```yaml
domain_events:
  user.created:
    description: Emitted when a new user account is created
    payload:
      user_id: { type: uuid }
      email: { type: string }
      name: { type: string }
      created_at: { type: datetime }
    consumers: [notification-service, analytics-service]

  user.verified:
    description: Emitted when user verifies their email
    payload:
      user_id: { type: uuid }
      verified_at: { type: datetime }
    consumers: [user-service (update status)]
```

## Contract Validation Rules

```
FOR BACKEND DEV:
  - Response body MUST match contract schema exactly
  - Status codes MUST match contract for each scenario
  - Error format MUST follow global error contract
  - Rate limits MUST be implemented as specified
  - Write contract tests that validate every response schema

FOR FRONTEND DEV:
  - Request format MUST match contract exactly
  - Handle ALL response codes listed in contract
  - Display appropriate UI for each error code
  - Respect rate limit headers (Retry-After)
  - Use TypeScript interfaces generated from contract

FOR QA:
  - Write contract compliance tests for every endpoint
  - Test every response code path
  - Test boundary values (min/max lengths, pagination limits)
  - Test error format consistency
```

# Skill: API Endpoint Implementation

> Load this skill when: Building REST API endpoints from the Architect's
> API contracts. Covers routing, validation, error handling, and middleware.

## Context

In 100% AI development, your API is consumed by the Frontend Dev agent's code.
The contract is your interface — deviate from it and the frontend breaks silently.
Follow the contract EXACTLY. Every status code, every field name, every error format.

## API Implementation Protocol

### Phase 1: Validate Contract Inputs

Before writing ANY code, verify you have:

```
REQUIRED INPUTS:
  [ ] API contract from Architect (endpoint spec with request/response schemas)
  [ ] Domain model from Domain Expert (entities, invariants, value objects)
  [ ] Acceptance criteria from PM (what behavior to implement)
  [ ] Database schema (if data persistence is needed)
```

### Phase 2: Project Structure

Follow clean architecture — routes are THIN:

```python
# project structure
app/
├── api/
│   ├── routes/
│   │   ├── __init__.py          # Router registration
│   │   └── users.py             # Route handlers (THIN — no logic here)
│   ├── schemas/
│   │   └── user_schemas.py      # Request/Response Pydantic models
│   ├── dependencies/
│   │   ├── auth.py              # Authentication dependency
│   │   └── database.py          # DB session injection
│   └── middleware/
│       ├── error_handler.py     # Global error formatting
│       └── rate_limiter.py      # Rate limiting
├── domain/
│   ├── models/
│   │   └── user.py              # Domain entity (business logic lives HERE)
│   ├── services/
│   │   └── user_service.py      # Use cases / application logic
│   ├── events/
│   │   └── user_events.py       # Domain events
│   └── exceptions.py            # Domain-specific exceptions
├── infrastructure/
│   ├── repositories/
│   │   └── user_repository.py   # Data access (SQL queries)
│   ├── database/
│   │   ├── connection.py        # DB connection pool
│   │   └── migrations/          # Alembic migrations
│   └── external/
│       └── email_service.py     # External API integrations
└── tests/
    ├── unit/
    ├── integration/
    └── conftest.py              # Shared fixtures
```

### Phase 3: Implementation Order (TDD)

```
FOR EACH ENDPOINT:

1. Define Pydantic schemas (request + response)
   → Match EXACTLY to architect's contract
   → Include validation rules (min/max, regex, enums)

2. Write failing test for happy path
   → Test the service layer, not the route

3. Implement domain entity/service method
   → Business logic in domain layer
   → Service orchestrates: validate → execute → emit event

4. Write failing test for route handler
   → Test HTTP status codes, response format

5. Implement route handler
   → Parse request → Call service → Format response
   → Route should be < 15 lines

6. Write failing tests for error cases
   → Each error status code from contract gets a test

7. Implement error handling
   → Domain exceptions → HTTP error responses
   → Follow global error format from contract

8. Write integration test
   → Real DB, full request/response cycle
```

### Phase 4: Route Handler Pattern

```python
# GOOD — Thin route, logic in service
@router.post("/users", status_code=201, response_model=UserResponse)
async def create_user(
    request: CreateUserRequest,
    service: UserService = Depends(get_user_service),
):
    try:
        user = await service.create_user(
            email=request.email,
            password=request.password,
            name=request.name,
        )
        return UserResponse.from_domain(user)
    except EmailAlreadyExistsError:
        raise HTTPException(status_code=409, detail={
            "error": "email_taken",
            "message": "An account with this email already exists"
        })
    except ValidationError as e:
        raise HTTPException(status_code=422, detail={
            "error": "validation_failed",
            "details": e.field_errors
        })


# BAD — Logic in route handler
@router.post("/users")
async def create_user(request: Request):
    data = await request.json()
    # DON'T: validation logic here
    # DON'T: database queries here
    # DON'T: business rules here
    # DON'T: email sending here
```

### Phase 5: Error Handling Strategy

```python
# Domain exceptions → HTTP mapping
ERROR_MAPPING = {
    EntityNotFoundError:     (404, "not_found"),
    EmailAlreadyExistsError: (409, "email_taken"),
    ValidationError:         (422, "validation_failed"),
    UnauthorizedError:       (401, "unauthorized"),
    ForbiddenError:          (403, "forbidden"),
    RateLimitExceededError:  (429, "rate_limited"),
}

# Global error handler middleware
@app.exception_handler(DomainError)
async def domain_error_handler(request: Request, exc: DomainError):
    status_code, error_code = ERROR_MAPPING.get(
        type(exc), (500, "internal_error")
    )
    return JSONResponse(
        status_code=status_code,
        content={
            "error": error_code,
            "message": str(exc),
            "request_id": request.state.request_id,
        }
    )
```

### Phase 6: Contract Compliance Verification

After implementation, verify:

```
CONTRACT COMPLIANCE CHECKLIST:
  [ ] Every endpoint from contract is implemented
  [ ] HTTP methods match (POST, GET, PATCH, DELETE)
  [ ] URL paths match exactly (including version prefix)
  [ ] Request body schema matches (field names, types, required/optional)
  [ ] Response body schema matches for EVERY status code
  [ ] Error response format matches global error contract
  [ ] Rate limits are implemented as specified
  [ ] Auth requirements match (public vs authenticated vs admin)
  [ ] Pagination format matches (if applicable)
  [ ] Headers match (Location, Retry-After, etc.)
```

## Output Format

```json
{
  "task_id": "T-001-02",
  "status": "DONE",
  "endpoints_implemented": [
    {
      "method": "POST",
      "path": "/api/v1/users",
      "contract_compliant": true,
      "tests": 6,
      "status_codes_covered": [201, 409, 422, 429]
    }
  ],
  "files_created": [
    "api/routes/users.py",
    "api/schemas/user_schemas.py",
    "domain/services/user_service.py",
    "tests/unit/test_user_service.py",
    "tests/integration/test_users_api.py"
  ],
  "contract_compliance": "100%",
  "test_coverage": "92%"
}
```

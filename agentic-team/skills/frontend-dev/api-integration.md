# Skill: API Integration & Data Fetching

> Load this skill when: Frontend components need to consume backend APIs.
> Covers data fetching, caching, error handling, optimistic updates, and type safety.

## Context

In 100% AI development, the API contract is your ONLY interface to the backend.
The Backend Dev agent has no idea what your component expects. The contract is
the truth. Generate TypeScript types FROM the contract. Handle EVERY error code.
Never assume the API will succeed.

## API Integration Protocol

### Phase 1: Type Generation from Contract

```typescript
// Generate types that EXACTLY match the API contract

// FROM: Architect's contract for POST /api/v1/users
// TO: TypeScript interfaces

// Request types
export interface CreateUserRequest {
  email: string;       // RFC 5322, max 255
  password: string;    // min 8, max 128
  name: string;        // min 1, max 100
}

// Response types (one per status code)
export interface UserResponse {
  id: string;          // UUID
  email: string;
  name: string;
  role: 'user' | 'admin';
  status: 'pending' | 'active' | 'suspended';
  created_at: string;  // ISO 8601
}

export interface ValidationError {
  error: 'validation_failed';
  details: Array<{
    field: string;
    message: string;
    code: string;
  }>;
}

export interface ConflictError {
  error: 'email_taken';
  message: string;
}

// Pagination types (reusable)
export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    per_page: number;
    total_items: number;
    total_pages: number;
    has_next: boolean;
    has_prev: boolean;
  };
}
```

### Phase 2: API Client Layer

```typescript
// services/api-client.ts — Centralized API client

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? '/api/v1';

class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    public details?: unknown,
  ) {
    super(`API Error: ${status} ${code}`);
    this.name = 'ApiError';
  }
}

async function apiRequest<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const url = `${API_BASE}${path}`;

  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeaders(),
      ...options.headers,
    },
  });

  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    throw new ApiError(response.status, body.error ?? 'unknown', body);
  }

  // Handle 204 No Content
  if (response.status === 204) return undefined as T;

  return response.json();
}

// Typed API methods
export const api = {
  users: {
    create: (data: CreateUserRequest) =>
      apiRequest<UserResponse>('/users', {
        method: 'POST',
        body: JSON.stringify(data),
      }),

    getById: (id: string) =>
      apiRequest<UserResponse>(`/users/${encodeURIComponent(id)}`),

    list: (params: { page?: number; per_page?: number } = {}) => {
      const query = new URLSearchParams(
        Object.entries(params).map(([k, v]) => [k, String(v)])
      );
      return apiRequest<PaginatedResponse<UserResponse>>(
        `/users?${query.toString()}`
      );
    },

    update: (id: string, data: Partial<CreateUserRequest>) =>
      apiRequest<UserResponse>(`/users/${encodeURIComponent(id)}`, {
        method: 'PATCH',
        body: JSON.stringify(data),
      }),
  },
};
```

### Phase 3: Data Fetching Hooks (React Query / SWR)

```typescript
// hooks/useUser.ts

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/services/api-client';

// Query keys — centralized for cache invalidation
export const userKeys = {
  all: ['users'] as const,
  lists: () => [...userKeys.all, 'list'] as const,
  list: (params: Record<string, unknown>) => [...userKeys.lists(), params] as const,
  details: () => [...userKeys.all, 'detail'] as const,
  detail: (id: string) => [...userKeys.details(), id] as const,
};

// Fetch single user
export function useUser(id: string) {
  return useQuery({
    queryKey: userKeys.detail(id),
    queryFn: () => api.users.getById(id),
    enabled: Boolean(id), // Don't fetch if no ID
    retry: (count, error) => {
      if (error instanceof ApiError && error.status === 404) return false;
      return count < 3;
    },
  });
}

// Fetch user list with pagination
export function useUsers(params: { page?: number; per_page?: number } = {}) {
  return useQuery({
    queryKey: userKeys.list(params),
    queryFn: () => api.users.list(params),
    placeholderData: (prev) => prev, // Keep previous data during pagination
  });
}

// Create user mutation
export function useCreateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: api.users.create,
    onSuccess: (newUser) => {
      // Invalidate list cache
      queryClient.invalidateQueries({ queryKey: userKeys.lists() });
      // Optimistically add to cache
      queryClient.setQueryData(userKeys.detail(newUser.id), newUser);
    },
  });
}
```

### Phase 4: Error Handling in Components

```typescript
// EVERY API error code must be handled in the UI

function RegistrationPage() {
  const createUser = useCreateUser();

  const handleSubmit = async (data: CreateUserRequest) => {
    try {
      const user = await createUser.mutateAsync(data);
      router.push(`/verify-email?id=${user.id}`);
    } catch (error) {
      if (error instanceof ApiError) {
        switch (error.status) {
          case 409:
            // Email already taken — show inline error on email field
            setFieldError('email', 'An account with this email already exists');
            break;
          case 422:
            // Validation errors — map to field-level errors
            const details = (error.details as ValidationError).details;
            details.forEach(({ field, message }) => setFieldError(field, message));
            break;
          case 429:
            // Rate limited — show retry message
            setFormError('Too many attempts. Please try again in a minute.');
            break;
          default:
            // Unexpected error — generic message
            setFormError('Something went wrong. Please try again.');
            // Log for debugging
            console.error('Registration failed:', error);
        }
      } else {
        // Network error
        setFormError('Unable to connect. Check your internet connection.');
      }
    }
  };
}

// ERROR HANDLING RULES:
// 401 → Redirect to login (handle globally in API client)
// 403 → Show "Access Denied" message
// 404 → Show "Not Found" state
// 409 → Show field-specific conflict message
// 422 → Map to field-level validation errors
// 429 → Show rate limit message with Retry-After
// 500 → Show generic error with request ID for support
// Network Error → Show offline/connectivity message
```

### Phase 5: Loading & Optimistic UI Patterns

```typescript
// LOADING STATES — Never show a blank screen

// Pattern 1: Skeleton loading (preferred for known layouts)
if (isLoading) return <UserProfileSkeleton />;

// Pattern 2: Spinner (for indeterminate operations)
<Button disabled={isSubmitting}>
  {isSubmitting ? <Spinner size="sm" /> : 'Save'}
</Button>

// Pattern 3: Optimistic updates (instant feedback)
const updateUser = useMutation({
  mutationFn: api.users.update,
  onMutate: async (variables) => {
    // Cancel outgoing refetches
    await queryClient.cancelQueries({ queryKey: userKeys.detail(variables.id) });
    // Snapshot previous value
    const previous = queryClient.getQueryData(userKeys.detail(variables.id));
    // Optimistically update
    queryClient.setQueryData(userKeys.detail(variables.id), (old) => ({
      ...old,
      ...variables.data,
    }));
    return { previous };
  },
  onError: (err, variables, context) => {
    // Rollback on error
    queryClient.setQueryData(userKeys.detail(variables.id), context?.previous);
  },
});
```

## Output Format

```json
{
  "task_id": "T-002-03",
  "status": "DONE",
  "api_integrations": [
    {
      "endpoint": "POST /api/v1/users",
      "hook": "useCreateUser",
      "error_codes_handled": [409, 422, 429, 500, "network"],
      "loading_pattern": "button spinner + form disabled",
      "type_safe": true
    }
  ],
  "files": [
    "src/services/api-client.ts",
    "src/types/api.ts",
    "src/hooks/useUser.ts",
    "src/hooks/useUser.test.ts"
  ]
}
```

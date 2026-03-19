# Skill: Component-Driven Development

> Load this skill when: Building UI components from the UI/UX Agent's specs.
> Covers component architecture, state management, and testing.

## Context

In 100% AI development, components must be SELF-DOCUMENTING. No designer will
review your work visually — only tests and specs validate correctness. Every
component must handle ALL states (loading, error, empty, success), be accessible
by default, and match the design token system exactly.

## Component Development Protocol

### Phase 1: Component Analysis

Before writing code, analyze the UI/UX spec:

```
COMPONENT ANALYSIS:
  Name:        [ComponentName]
  Type:        [primitive | feature | layout | page]
  Props:       [list all props with types]
  States:      [all visual states: default, hover, active, focus, disabled, loading, error, empty]
  Variants:    [visual variants: primary, secondary, ghost, etc.]
  Children:    [what goes inside — slots, composition]
  Events:      [what it emits: onClick, onChange, onSubmit]
  Data Source:  [where data comes from: props, API, global state, URL params]
  Responsive:  [breakpoints and behavior changes]
  Accessibility: [ARIA roles, keyboard interactions, screen reader text]
```

### Phase 2: Component File Structure

```typescript
// Every component follows this structure:
src/components/features/UserForm/
├── UserForm.tsx           // Component implementation
├── UserForm.test.tsx      // Component tests
├── UserForm.types.ts      // TypeScript interfaces
├── UserForm.styles.ts     // Styled components or CSS modules
├── UserForm.stories.tsx   // Storybook stories (optional)
├── useUserForm.ts         // Custom hook (if complex logic)
└── index.ts               // Public export
```

### Phase 3: Component Implementation Template

```typescript
// UserForm.types.ts
export interface UserFormProps {
  /** Initial values for editing existing user */
  initialValues?: Partial<UserFormData>;
  /** Called when form is submitted with valid data */
  onSubmit: (data: UserFormData) => Promise<void>;
  /** Whether the form is in a loading state */
  isLoading?: boolean;
  /** Error message to display */
  error?: string | null;
  /** Visual variant */
  variant?: 'create' | 'edit';
}

export interface UserFormData {
  email: string;
  name: string;
  password: string;
}

// UserForm.tsx
import { type UserFormProps } from './UserForm.types';

export function UserForm({
  initialValues,
  onSubmit,
  isLoading = false,
  error = null,
  variant = 'create',
}: UserFormProps) {
  // 1. Hooks at the top (useState, useEffect, custom hooks)
  // 2. Derived state / computed values
  // 3. Event handlers
  // 4. Early returns for special states (loading, error)
  // 5. Main render

  if (isLoading) {
    return <FormSkeleton aria-label="Loading form" />;
  }

  return (
    <form onSubmit={handleSubmit} aria-label="User registration form" noValidate>
      {error && (
        <Alert role="alert" variant="error">
          {error}
        </Alert>
      )}

      {/* Form fields with inline validation */}
      <FormField
        label="Email"
        name="email"
        type="email"
        required
        error={errors.email}
        aria-describedby={errors.email ? 'email-error' : undefined}
      />

      {/* Submit button with loading state */}
      <Button
        type="submit"
        variant="primary"
        disabled={isSubmitting}
        aria-busy={isSubmitting}
      >
        {isSubmitting ? 'Creating...' : 'Create Account'}
      </Button>
    </form>
  );
}
```

### Phase 4: State Handling (ALL States Mandatory)

```typescript
// Every component that fetches data MUST handle all states:

function UserProfile({ userId }: { userId: string }) {
  const { data, error, isLoading } = useUser(userId);

  // STATE: Loading
  if (isLoading) {
    return <ProfileSkeleton aria-label="Loading profile" />;
  }

  // STATE: Error
  if (error) {
    return (
      <ErrorDisplay
        message="Failed to load profile"
        onRetry={() => refetch()}
        role="alert"
      />
    );
  }

  // STATE: Empty / Not Found
  if (!data) {
    return <EmptyState message="User not found" icon="user-x" />;
  }

  // STATE: Success
  return (
    <article aria-label={`Profile for ${data.name}`}>
      <h1>{data.name}</h1>
      <p>{data.email}</p>
    </article>
  );
}
```

### Phase 5: Accessibility Requirements (Non-Negotiable)

```
EVERY COMPONENT MUST:

SEMANTICS:
  [ ] Use semantic HTML elements (button, nav, main, article, not div for everything)
  [ ] Have a role attribute if semantic element isn't available
  [ ] Have aria-label or aria-labelledby for non-text content
  [ ] Use heading hierarchy (h1 → h2 → h3, no skipping)

KEYBOARD:
  [ ] All interactive elements focusable (tab order)
  [ ] Enter/Space activates buttons and links
  [ ] Escape closes modals/dropdowns
  [ ] Arrow keys navigate within composites (tabs, menus, lists)
  [ ] Focus visible indicator (not just outline: none)
  [ ] Focus trap in modals (tab doesn't leave modal)

SCREEN READER:
  [ ] aria-live="polite" for dynamic content updates
  [ ] aria-busy="true" during loading states
  [ ] role="alert" for error messages
  [ ] aria-expanded for collapsible sections
  [ ] aria-selected for selectable items
  [ ] Descriptive link text (not "click here")

VISUAL:
  [ ] Color contrast 4.5:1 for text (3:1 for large text)
  [ ] Information not conveyed by color alone (use icons + text)
  [ ] Touch target minimum 48x48px
  [ ] Respects prefers-reduced-motion
  [ ] Respects prefers-color-scheme
```

### Phase 6: Testing Protocol

```typescript
// Component Test Template (React Testing Library)

describe('UserForm', () => {
  // Test: Renders correctly with default props
  it('renders all form fields', () => {
    render(<UserForm onSubmit={vi.fn()} />);
    expect(screen.getByLabelText('Email')).toBeInTheDocument();
    expect(screen.getByLabelText('Name')).toBeInTheDocument();
    expect(screen.getByLabelText('Password')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Create Account' })).toBeInTheDocument();
  });

  // Test: Handles user interaction
  it('calls onSubmit with form data when submitted', async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);
    render(<UserForm onSubmit={onSubmit} />);

    await userEvent.type(screen.getByLabelText('Email'), 'jane@example.com');
    await userEvent.type(screen.getByLabelText('Name'), 'Jane Doe');
    await userEvent.type(screen.getByLabelText('Password'), 'SecureP@ss123');
    await userEvent.click(screen.getByRole('button', { name: 'Create Account' }));

    expect(onSubmit).toHaveBeenCalledWith({
      email: 'jane@example.com',
      name: 'Jane Doe',
      password: 'SecureP@ss123',
    });
  });

  // Test: Shows validation errors
  it('shows validation error for invalid email', async () => {
    render(<UserForm onSubmit={vi.fn()} />);
    await userEvent.type(screen.getByLabelText('Email'), 'not-an-email');
    await userEvent.click(screen.getByRole('button', { name: 'Create Account' }));
    expect(screen.getByText('Please enter a valid email')).toBeInTheDocument();
  });

  // Test: Loading state
  it('shows loading skeleton when isLoading is true', () => {
    render(<UserForm onSubmit={vi.fn()} isLoading />);
    expect(screen.getByLabelText('Loading form')).toBeInTheDocument();
  });

  // Test: Error state
  it('displays error message in alert role', () => {
    render(<UserForm onSubmit={vi.fn()} error="Email already taken" />);
    expect(screen.getByRole('alert')).toHaveTextContent('Email already taken');
  });

  // Test: Accessibility
  it('has no accessibility violations', async () => {
    const { container } = render(<UserForm onSubmit={vi.fn()} />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });
});
```

## Output Format

```json
{
  "task_id": "T-002-02",
  "status": "DONE",
  "components_created": [
    {
      "name": "UserForm",
      "type": "feature",
      "states_handled": ["default", "loading", "error", "submitting", "success"],
      "accessibility": "WCAG 2.1 AA compliant",
      "tests": 8,
      "responsive": true
    }
  ],
  "files": [
    "src/components/features/UserForm/UserForm.tsx",
    "src/components/features/UserForm/UserForm.test.tsx",
    "src/components/features/UserForm/UserForm.types.ts",
    "src/components/features/UserForm/index.ts"
  ]
}
```

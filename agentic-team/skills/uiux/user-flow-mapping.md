# Skill: User Flow Mapping & Interaction Design

> Load this skill when: A new feature needs user journey mapping, wireframes,
> or interaction pattern definitions before component development begins.

## Context

In 100% AI development, user flows are EXECUTABLE SPECIFICATIONS. The Frontend
Dev agent reads your flow and builds exactly those screens, states, and transitions.
If a screen state isn't in your flow, it won't be built. Be exhaustive — map
every click, every error, every edge case in the journey.

## User Flow Protocol

### Phase 1: Journey Mapping

```
FEATURE: User Registration

ENTRY POINTS:
  1. Direct URL: /register
  2. CTA button on landing page
  3. Login page "Create account" link
  4. Invite email link (with pre-filled email)

USER GOAL: Create an account and access the application

FLOW:
  ┌─────────────────────┐
  │   REGISTRATION PAGE  │
  │                      │
  │  [Email field]       │
  │  [Name field]        │
  │  [Password field]    │
  │  [Show password toggle]
  │  Password strength:  │
  │  ████░░░░ Medium     │
  │                      │
  │  [Create Account]    │
  │                      │
  │  Already have one?   │
  │  [Log in] link       │
  └──────────┬───────────┘
             │
    ┌────────┼────────────────────┐
    │        │                    │
    ▼        ▼                    ▼
  SUCCESS  VALIDATION          SERVER
  (201)    ERROR (422)         ERROR (409/500)
    │        │                    │
    │    Show inline              │
    │    field errors         Show toast/
    │    ← stay on page       banner error
    │                         ← stay on page
    │
    ▼
  ┌──────────────────────┐
  │  EMAIL VERIFICATION   │
  │                       │
  │  "Check your email"   │
  │  [illustration]       │
  │                       │
  │  Didn't get it?       │
  │  [Resend] button      │
  │  (cooldown: 60s)      │
  │                       │
  │  [Change email] link  │
  └──────────┬────────────┘
             │
    ┌────────┼───────────┐
    │        │           │
    ▼        ▼           ▼
  CLICKED  EXPIRED    INVALID
  LINK     LINK       LINK
  (valid)  (>24hr)    (bad token)
    │        │           │
    ▼        │           │
  ┌──────┐   │           │
  │WELCOME│  Show         Show
  │PAGE   │  "Link        "Invalid
  │       │  expired,     link" error
  │[Start]│  resend?"     + resend
  └───────┘  button       option
```

### Phase 2: Screen State Matrix

For EVERY screen, define ALL possible states:

```
SCREEN: Registration Page

| State | Trigger | Visual | Actions Available |
|-------|---------|--------|-------------------|
| Empty | Page load | All fields empty, button disabled | Type in fields |
| Filling | User types | Fields have content, live validation | Continue typing, submit |
| Validating | User submits | Button shows spinner | Wait |
| Field Error | Validation fails | Red borders on invalid fields, error text below | Fix fields, resubmit |
| Server Error | 409/500 response | Toast/banner with error message | Dismiss, retry |
| Success | 201 response | Redirect to email verification page | N/A |
| Pre-filled | Invite link | Email pre-filled and disabled | Fill remaining fields |
| Rate Limited | 429 response | "Try again in X seconds" message | Wait, retry |
| Offline | No network | "No internet connection" banner | Retry when online |

FIELD STATES:
| Field State | Visual | Trigger |
|-------------|--------|---------|
| Empty | Placeholder text, gray border | Default |
| Focused | Blue border, label floated | Click/tab into field |
| Filled | Content visible, gray border | User typed content |
| Valid | Green check icon (subtle) | Passes validation |
| Invalid | Red border, error text below | Fails validation |
| Disabled | Gray background, no cursor | Pre-filled from invite |
```

### Phase 3: Interaction Specification

```
INTERACTION: Password Strength Indicator

TRIGGER: User types in password field (onChange)

BEHAVIOR:
  On each keystroke:
    1. Calculate strength score (0-4)
    2. Update progress bar
    3. Update label text
    4. Update color

  STRENGTH LEVELS:
    0 — Very Weak  → 1 bar  → red    → "Very weak"
    1 — Weak       → 2 bars → red    → "Weak"
    2 — Fair       → 3 bars → amber  → "Fair"
    3 — Strong     → 4 bars → green  → "Strong"
    4 — Very Strong→ 5 bars → green  → "Very strong"

  CRITERIA (show as checklist below indicator):
    [ ] At least 8 characters
    [ ] Contains uppercase letter
    [ ] Contains lowercase letter
    [ ] Contains number
    [ ] Contains special character

  ANIMATION:
    Bar width transition: 200ms ease-out
    Color transition: 150ms ease

  ACCESSIBILITY:
    aria-live="polite" on strength label
    aria-valuenow={score} aria-valuemin={0} aria-valuemax={4}
    Screen reader: "Password strength: Strong. 4 of 5 criteria met."
```

### Phase 4: Error Message Specification

```
ERROR MESSAGES (exact text for Frontend Dev):

FIELD VALIDATION:
  email:
    empty:     "Email is required"
    invalid:   "Please enter a valid email address"
    too_long:  "Email must be less than 255 characters"

  name:
    empty:     "Name is required"
    too_long:  "Name must be less than 100 characters"

  password:
    empty:     "Password is required"
    too_short: "Password must be at least 8 characters"
    too_long:  "Password must be less than 128 characters"
    too_weak:  "Password must include uppercase, lowercase, number, and special character"

SERVER ERRORS:
  409: "An account with this email already exists. [Log in instead?]"
  429: "Too many attempts. Please try again in {retry_after} seconds."
  500: "Something went wrong. Please try again. If the problem persists, contact support."
  network: "Unable to connect. Please check your internet connection and try again."

ERROR DISPLAY RULES:
  - Field errors: Show below the field, red text, red border on field
  - Server errors: Show as toast notification (dismissable, 8s auto-dismiss)
  - Network errors: Show as persistent banner at top (until connection restored)
  - Never show technical details (stack traces, error codes) to users
```

### Phase 5: Responsive Behavior

```
BREAKPOINT BEHAVIORS:

MOBILE (< 768px):
  - Single column layout
  - Full-width form fields
  - Full-width submit button
  - Sticky submit button at bottom (above keyboard)
  - Password strength: simplified (bar only, no checklist)
  - Social login buttons: stacked vertically

TABLET (768px - 1024px):
  - Centered card layout (max-width: 480px)
  - Standard form fields
  - Standard submit button
  - Full password strength indicator

DESKTOP (> 1024px):
  - Split layout: illustration left, form right
  - Or centered card with max-width: 420px
  - Full password strength indicator
  - Keyboard shortcuts: Enter to submit
```

## Output Format

```json
{
  "task_id": "T-002-01",
  "status": "DONE",
  "deliverables": {
    "user_flow": "specs/flows/registration-flow.md",
    "screen_states": 10,
    "interactions_specified": 5,
    "error_messages": 12,
    "responsive_breakpoints": 3
  },
  "screens_defined": [
    "Registration Page (9 states)",
    "Email Verification Page (4 states)",
    "Welcome Page (1 state)"
  ],
  "handoff_ready": true,
  "handoff_to": "frontend_dev"
}
```

# Skill: Design System & Token Architecture

> Load this skill when: A new project needs a design foundation, or components
> need consistent visual language across the application.

## Context

In 100% AI development, the design system is a MACHINE-READABLE specification.
The Frontend Dev agent reads design tokens as JSON/TypeScript — not Figma files.
Every color, spacing value, font, shadow, and animation must be defined as a
token with semantic naming. Consistency is automatic when tokens are the only
way to apply visual properties.

## Design System Protocol

### Phase 1: Token Architecture

```
TOKEN HIERARCHY:

Level 1 — PRIMITIVE TOKENS (raw values, never use directly in components):
  color.blue.500: "#3b82f6"
  spacing.4: "1rem"
  font.size.16: "1rem"

Level 2 — SEMANTIC TOKENS (meaning-based, USE THESE in components):
  color.primary: color.blue.500
  color.error: color.red.500
  spacing.component.gap: spacing.4
  font.body: font.size.16

Level 3 — COMPONENT TOKENS (component-specific overrides):
  button.primary.background: color.primary
  button.primary.text: color.white
  button.primary.hover.background: color.blue.600
  input.border: color.gray.300
  input.focus.border: color.primary
```

### Phase 2: Complete Token Specification

```json
{
  "color": {
    "primitive": {
      "gray": {
        "50": "#f9fafb", "100": "#f3f4f6", "200": "#e5e7eb",
        "300": "#d1d5db", "400": "#9ca3af", "500": "#6b7280",
        "600": "#4b5563", "700": "#374151", "800": "#1f2937",
        "900": "#111827", "950": "#030712"
      },
      "blue": {
        "50": "#eff6ff", "100": "#dbeafe", "200": "#bfdbfe",
        "300": "#93c5fd", "400": "#60a5fa", "500": "#3b82f6",
        "600": "#2563eb", "700": "#1d4ed8", "800": "#1e40af",
        "900": "#1e3a8a"
      },
      "red": {
        "50": "#fef2f2", "500": "#ef4444", "600": "#dc2626", "700": "#b91c1c"
      },
      "green": {
        "50": "#f0fdf4", "500": "#22c55e", "600": "#16a34a", "700": "#15803d"
      },
      "amber": {
        "50": "#fffbeb", "500": "#f59e0b", "600": "#d97706", "700": "#b45309"
      }
    },
    "semantic": {
      "primary": "blue.500",
      "primary-hover": "blue.600",
      "primary-active": "blue.700",
      "secondary": "gray.600",
      "secondary-hover": "gray.700",
      "success": "green.500",
      "error": "red.500",
      "warning": "amber.500",
      "info": "blue.500",
      "text-primary": "gray.900",
      "text-secondary": "gray.600",
      "text-muted": "gray.400",
      "text-on-primary": "white",
      "bg-primary": "white",
      "bg-secondary": "gray.50",
      "bg-tertiary": "gray.100",
      "border-default": "gray.200",
      "border-focus": "blue.500",
      "border-error": "red.500"
    }
  },

  "typography": {
    "font-family": {
      "sans": "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
      "mono": "'JetBrains Mono', 'Fira Code', monospace"
    },
    "scale": {
      "xs":   { "size": "0.75rem",  "line-height": "1rem",    "letter-spacing": "0" },
      "sm":   { "size": "0.875rem", "line-height": "1.25rem", "letter-spacing": "0" },
      "base": { "size": "1rem",     "line-height": "1.5rem",  "letter-spacing": "0" },
      "lg":   { "size": "1.125rem", "line-height": "1.75rem", "letter-spacing": "-0.01em" },
      "xl":   { "size": "1.25rem",  "line-height": "1.75rem", "letter-spacing": "-0.01em" },
      "2xl":  { "size": "1.5rem",   "line-height": "2rem",    "letter-spacing": "-0.02em" },
      "3xl":  { "size": "1.875rem", "line-height": "2.25rem", "letter-spacing": "-0.02em" },
      "4xl":  { "size": "2.25rem",  "line-height": "2.5rem",  "letter-spacing": "-0.03em" }
    },
    "weight": {
      "normal": 400,
      "medium": 500,
      "semibold": 600,
      "bold": 700
    }
  },

  "spacing": {
    "0": "0",
    "1": "0.25rem",
    "2": "0.5rem",
    "3": "0.75rem",
    "4": "1rem",
    "5": "1.25rem",
    "6": "1.5rem",
    "8": "2rem",
    "10": "2.5rem",
    "12": "3rem",
    "16": "4rem",
    "20": "5rem",
    "semantic": {
      "page-padding": "spacing.6",
      "section-gap": "spacing.8",
      "component-gap": "spacing.4",
      "element-gap": "spacing.2",
      "inline-gap": "spacing.1"
    }
  },

  "radius": {
    "none": "0",
    "sm": "0.25rem",
    "md": "0.375rem",
    "lg": "0.5rem",
    "xl": "0.75rem",
    "2xl": "1rem",
    "full": "9999px"
  },

  "shadow": {
    "sm": "0 1px 2px 0 rgb(0 0 0 / 0.05)",
    "md": "0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)",
    "lg": "0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)",
    "xl": "0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)"
  },

  "breakpoints": {
    "sm": "640px",
    "md": "768px",
    "lg": "1024px",
    "xl": "1280px",
    "2xl": "1536px"
  },

  "animation": {
    "duration": {
      "fast": "150ms",
      "normal": "200ms",
      "slow": "300ms"
    },
    "easing": {
      "default": "cubic-bezier(0.4, 0, 0.2, 1)",
      "in": "cubic-bezier(0.4, 0, 1, 1)",
      "out": "cubic-bezier(0, 0, 0.2, 1)"
    }
  },

  "z-index": {
    "dropdown": 10,
    "sticky": 20,
    "overlay": 30,
    "modal": 40,
    "toast": 50
  }
}
```

### Phase 3: Component Spec Template

For each UI component, produce:

```
COMPONENT: Button

VARIANTS:
  primary:   bg=primary, text=white, hover=primary-hover
  secondary: bg=transparent, text=secondary, border=border-default, hover=bg-secondary
  ghost:     bg=transparent, text=secondary, hover=bg-secondary
  danger:    bg=error, text=white, hover=red.600

SIZES:
  sm: h=32px, px=spacing.3, font=sm, radius=md
  md: h=40px, px=spacing.4, font=base, radius=md
  lg: h=48px, px=spacing.5, font=lg, radius=lg

STATES:
  default:  [base styles per variant]
  hover:    [hover styles — background shift, subtle transform]
  active:   [pressed — darker background, scale(0.98)]
  focus:    [2px ring, ring-color=primary, ring-offset=2px]
  disabled: [opacity=0.5, cursor=not-allowed, no hover effect]
  loading:  [spinner replaces text, same dimensions, disabled interaction]

ACCESSIBILITY:
  role: button
  keyboard: Enter/Space triggers onClick
  aria-disabled: true when disabled (don't remove from tab order)
  aria-busy: true when loading
  focus-visible: ring style (not outline: none)
  min touch target: 44x44px (sm size allowed only for inline actions)

RESPONSIVE:
  mobile: full-width in forms, auto-width in toolbars
  desktop: auto-width everywhere
```

### Phase 4: Dark Mode Token Mapping

```json
{
  "light": {
    "text-primary": "gray.900",
    "text-secondary": "gray.600",
    "bg-primary": "white",
    "bg-secondary": "gray.50",
    "border-default": "gray.200"
  },
  "dark": {
    "text-primary": "gray.50",
    "text-secondary": "gray.400",
    "bg-primary": "gray.900",
    "bg-secondary": "gray.800",
    "border-default": "gray.700"
  }
}
```

## Output Format

```json
{
  "task_id": "T-002-01",
  "status": "DONE",
  "deliverables": {
    "token_file": "src/design/tokens.ts",
    "theme_config": "src/design/theme.ts",
    "component_specs": 12,
    "dark_mode": true
  },
  "token_counts": {
    "colors": 42,
    "spacing": 18,
    "typography": 24,
    "shadows": 4,
    "radii": 7,
    "breakpoints": 5,
    "animations": 6
  }
}
```

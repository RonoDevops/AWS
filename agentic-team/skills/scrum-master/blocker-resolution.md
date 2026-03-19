# Skill: Blocker Detection & Resolution

> Load this skill when: An agent reports BLOCKED status, a task exceeds its time
> estimate, or the sprint board shows stalled progress.

## Context

In 100% AI development, blockers don't announce themselves politely. You must
actively monitor for them, diagnose root cause, and resolve or escalate —
because there's no standup meeting where someone says "I'm stuck."

## Blocker Detection Patterns

### Pattern 1: Agent Reports BLOCKED

```
TRIGGER: Agent returns status = "BLOCKED"

DIAGNOSIS PROTOCOL:
1. Read the agent's blocker description
2. Classify the blocker:

   TYPE A — Missing Input:
     Agent needs an artifact that hasn't been produced yet.
     → Check: Is the producing task done? Is there a dependency gap?
     → Fix: Re-order tasks, or fast-track the producing task

   TYPE B — Failed Dependency:
     A dependency exists but is broken/incompatible.
     → Check: Does the API contract match? Schema mismatch? Version conflict?
     → Fix: Send back to producing agent with specific mismatch details

   TYPE C — Technical Limitation:
     The approach doesn't work (API doesn't exist, service unavailable, etc.)
     → Check: Is there an alternative approach? Can Architect suggest one?
     → Fix: Route to Architect for design pivot

   TYPE D — Ambiguous Requirements:
     Agent doesn't know what to build.
     → Check: Are acceptance criteria clear? Is the story well-defined?
     → Fix: Route back to PM for clarification

   TYPE E — Cascading Failure:
     One failure caused multiple downstream tasks to block.
     → Check: Which task is the root cause?
     → Fix: Resolve root cause FIRST, then unblock downstream
```

### Pattern 2: Silent Stall (No Progress)

```
TRIGGER: Task has been IN_PROGRESS for > 2x its estimated effort

DIAGNOSIS:
1. Check agent's last output — is it producing partial results?
2. Check for infinite loops — is the agent retrying the same failing approach?
3. Check for scope creep — is the agent doing more than the task asks?

RESOLUTION:
  If looping:     Kill and reassign with explicit constraints
  If scope creep: Reset to original task scope, create new task for extras
  If stuck:       Decompose into smaller sub-tasks
```

### Pattern 3: Review Loop Stuck

```
TRIGGER: Code review → fix → review → fix cycle > 3 iterations

DIAGNOSIS:
1. Are review comments contradictory? (Reviewer says X, then says not-X)
2. Is the agent misunderstanding the feedback?
3. Is the reviewer too strict for the task's importance?

RESOLUTION:
  If contradictory:     Escalate to Architect for definitive ruling
  If misunderstanding:  Provide explicit code example of expected fix
  If over-strict:       Evaluate: is perfection worth the delay? Accept with tech debt ticket
```

## Resolution Decision Tree

```
BLOCKER DETECTED
    │
    ├── Can another agent unblock it?
    │     YES → Reassign/fast-track the unblocking task
    │     NO  ↓
    │
    ├── Can the task be redesigned to avoid the blocker?
    │     YES → Route to Architect for alternative approach
    │     NO  ↓
    │
    ├── Is it a requirements gap?
    │     YES → Route to PM for clarification
    │     NO  ↓
    │
    ├── Is it a technical limitation we can't solve?
    │     YES → Escalate to human with full context
    │     NO  ↓
    │
    └── Decompose: Split the blocked task into smaller pieces
          → Some pieces may be unblocked
          → Blocked piece gets explicit dependency added
```

## Blocker Report Format

```json
{
  "blocker_id": "BLK-001",
  "task_id": "T-002-03",
  "agent": "frontend_dev",
  "type": "missing_input",
  "description": "POST /users endpoint returns 500 — cannot implement registration form",
  "root_cause": "T-001-02 has a bug in input validation — rejects valid emails",
  "resolution": "Sent T-001-02 back to backend_dev with specific failing input",
  "resolved_at": "2026-03-19T14:30:00Z",
  "time_lost": "25 minutes",
  "preventable": true,
  "prevention": "Add contract validation test to backend tasks"
}
```

## Escalation Protocol

```
Level 1: Scrum Master resolves (reorder, reassign, decompose)     → 90% of blockers
Level 2: Architect resolves (design pivot, alternative approach)   → 8% of blockers
Level 3: Human resolves (external dependency, business decision)   → 2% of blockers

ESCALATION TRIGGER TO HUMAN:
  - External API/service is down and no workaround exists
  - Business requirement is contradictory
  - Budget/cost decision needed
  - Legal/compliance question
  - > 3 agents blocked on same root cause
```

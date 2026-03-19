# Skill: Sprint Retrospective & Continuous Improvement

> Load this skill when: A sprint is complete (accepted or rejected) and the team
> needs to analyze what worked, what didn't, and what to improve.

## Context

In 100% AI development, retrospectives analyze AGENT PERFORMANCE, not human feelings.
We optimize for: fewer blockers, faster execution, higher first-pass quality,
and better inter-agent communication. Every retro produces actionable improvements
that get encoded into agent prompts or workflow rules.

## Retrospective Protocol

### Phase 1: Sprint Metrics Collection

```
SPRINT METRICS:
  Sprint ID:              S-[NNN]
  Sprint Goal:            [statement]
  Goal Met:               [YES | PARTIAL | NO]

  VELOCITY:
    Stories planned:       [N]
    Stories completed:     [N]
    Stories carried over:  [N]
    Completion rate:       [N%]

  QUALITY:
    First-pass test rate:  [% of tasks that passed tests on first attempt]
    Code review cycles:    [avg cycles before approval — target: < 2]
    Bugs found in QA:      [count — lower is better]
    Security findings:     [critical: N, high: N, medium: N]
    Rework tasks:          [tasks sent back for fixes]

  EFFICIENCY:
    Total AI execution time:   [hours]
    Time blocked:              [hours — wasted time]
    Blocker count:             [N]
    Avg blocker resolution:    [minutes]
    Parallelism achieved:      [% — how much work ran in parallel vs sequential]

  COMMUNICATION:
    Handoff failures:     [times an agent received wrong/incomplete input]
    Contract mismatches:  [times output didn't match expected schema]
    Scope changes:        [mid-sprint story changes]
```

### Phase 2: Pattern Analysis

Identify recurring patterns:

```
WHAT WENT WELL (keep doing):
  Pattern: [Description]
  Evidence: [Specific examples from this sprint]
  Action: [Encode into skill/prompt — make it permanent]

WHAT WENT WRONG (stop doing):
  Pattern: [Description]
  Evidence: [Specific failures]
  Root Cause: [Why it happened — not just what happened]
  Action: [Change to skill/prompt/workflow to prevent recurrence]

WHAT TO TRY (experiment):
  Hypothesis: [If we change X, then Y should improve]
  Experiment: [What specifically to try next sprint]
  Measure: [How to know if it worked]
```

### Phase 3: Agent Performance Review

Rate each agent on key dimensions:

```
AGENT: backend_dev
  Task completion:    [5/5 tasks done]
  First-pass quality: [4/5 passed tests first time]
  Contract adherence: [5/5 matched API specs]
  Test coverage:      [92% average]
  Blockers caused:    [1 — validation bug blocked frontend]
  Rating: ★★★★☆
  Improvement: "Add contract validation tests before marking task DONE"

AGENT: frontend_dev
  Task completion:    [3/3 tasks done]
  First-pass quality: [2/3 passed first time]
  Accessibility:      [3/3 WCAG compliant]
  Blockers caused:    [0]
  Rating: ★★★★★
  Improvement: "None — maintain current quality"
```

### Phase 4: Improvement Actions

Every improvement MUST be one of these types:

```
TYPE 1: PROMPT UPDATE
  Change an agent's prompt/skill to prevent a recurring issue.
  Example: "Add to backend_dev TDD skill: Run contract validation
           test against architect's OpenAPI spec before marking DONE"

TYPE 2: WORKFLOW CHANGE
  Add, remove, or reorder steps in the LangGraph flow.
  Example: "Add a contract validation node between dev tasks and QA"

TYPE 3: NEW SKILL
  Create a new skill for a gap that was discovered.
  Example: "Create 'performance-baseline' skill for QA agent to run
           load tests before sprint acceptance"

TYPE 4: GATE ADDITION
  Add a new quality gate that prevents a class of bugs.
  Example: "Add API contract match gate — no task moves to DONE
           unless response schema matches architect's spec"

TYPE 5: TASK TEMPLATE UPDATE
  Improve how tasks are decomposed or described.
  Example: "Always include example request/response payloads
           in API implementation tasks"
```

### Phase 5: Retrospective Report

```json
{
  "sprint_id": "S-001",
  "date": "2026-03-19",
  "velocity": {
    "planned": 7,
    "completed": 6,
    "carried_over": 1,
    "rate": "86%"
  },
  "quality": {
    "first_pass_rate": "78%",
    "avg_review_cycles": 1.8,
    "bugs_in_qa": 3,
    "security_findings": {"critical": 0, "high": 1, "medium": 2}
  },
  "efficiency": {
    "total_time": "10.5 hours",
    "blocked_time": "1.2 hours",
    "parallelism": "65%"
  },
  "improvements": [
    {
      "type": "prompt_update",
      "target": "backend_dev",
      "change": "Add contract validation step to TDD skill",
      "expected_impact": "Reduce handoff failures by 50%"
    },
    {
      "type": "gate_addition",
      "target": "workflow",
      "change": "Add schema validation gate between dev and QA",
      "expected_impact": "Catch contract mismatches before QA"
    }
  ],
  "next_sprint_focus": "Improve first-pass quality to >85%"
}
```

## Continuous Improvement Loop

```
Sprint N retro produces improvements
    → Improvements encoded into prompts/skills/workflow
    → Sprint N+1 executes with improvements
    → Sprint N+1 retro measures if improvements worked
    → Repeat — the team gets better every sprint
```

This is the AI equivalent of kaizen — continuous, measurable, compounding improvement.

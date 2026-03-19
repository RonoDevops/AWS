# Agile Agentic AI Team — LangGraph + LangSmith

## Team Architecture

```
                          ┌─────────────────┐
                          │   HUMAN OWNER   │
                          │  (Product Owner) │
                          └────────┬────────┘
                                   │
                          ┌────────▼────────┐
                          │   PM AGENT      │
                          │  (Orchestrator)  │
                          └────────┬────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                     │
     ┌────────▼────────┐ ┌────────▼────────┐  ┌────────▼────────┐
     │  ARCHITECT AGENT│ │  SCRUM MASTER   │  │  DOMAIN EXPERT  │
     │  (System Design)│ │  (Sprint Ops)   │  │  (Biz Logic)    │
     └────────┬────────┘ └────────┬────────┘  └─────────────────┘
              │                    │
    ┌─────────┼─────────┐         │
    │         │         │         │
┌───▼──┐ ┌───▼──┐ ┌───▼───┐ ┌──▼───┐
│BACK- │ │FRONT-│ │INFRA/ │ │  QA  │
│END   │ │END   │ │DEVOPS │ │AGENT │
│DEV   │ │DEV   │ │AGENT  │ │      │
└───┬──┘ └───┬──┘ └───┬───┘ └──┬───┘
    │         │        │        │
    └─────────┼────────┼────────┘
              │        │
         ┌────▼────┐ ┌─▼──────────┐
         │ UI/UX   │ │  CLOUD     │
         │ AGENT   │ │  AGENT     │
         └─────────┘ └────────────┘
```

## Agent Roster (WHO → WHAT → HOW → WHERE)

| # | Agent | WHO | WHAT | HOW | WHERE (LangGraph Node) |
|---|-------|-----|------|-----|------------------------|
| 1 | **Product Manager** | Strategic leader, prioritizer | Gathers requirements, writes user stories, prioritizes backlog | Socratic questioning, MoSCoW prioritization, acceptance criteria | `pm_node` (entry router) |
| 2 | **Scrum Master** | Sprint operations manager | Runs sprints, tracks velocity, removes blockers, enforces process | Kanban state tracking, burndown analysis, escalation protocols | `scrum_node` (orchestrator) |
| 3 | **Architect** | System designer, tech decision maker | Designs architecture, selects patterns, defines contracts/APIs | C4 diagrams, ADRs, tech spike analysis, trade-off matrices | `architect_node` |
| 4 | **Domain Expert** | Business logic authority | Validates biz rules, edge cases, compliance, domain models | DDD patterns, ubiquitous language, invariant enforcement | `domain_node` |
| 5 | **Backend Dev** | Server-side engineer | Writes APIs, services, DB schemas, business logic code | TDD, SOLID, clean architecture, code review protocols | `backend_node` |
| 6 | **Frontend Dev** | Client-side engineer | Builds UI components, state management, API integration | Component-driven dev, accessibility, responsive design | `frontend_node` |
| 7 | **UI/UX Agent** | Design system authority | Creates wireframes, design tokens, interaction patterns | Design principles, Figma specs, accessibility (WCAG), user flows | `uiux_node` |
| 8 | **QA Agent** | Quality gatekeeper | Writes test plans, test cases, validates acceptance criteria | Test pyramid, BDD/TDD, regression analysis, bug triage | `qa_node` |
| 9 | **DevOps Agent** | CI/CD and automation engineer | Builds pipelines, IaC, monitoring, deployment strategies | GitHub Actions, Terraform, Docker, blue-green deploys | `devops_node` |
| 10 | **Cloud Agent** | Cloud infrastructure specialist | Provisions infra, manages services, cost optimization | AWS/GCP/Azure best practices, Well-Architected Framework | `cloud_node` |
| 11 | **Security Agent** | AppSec specialist | Threat modeling, code scanning, compliance checks | OWASP Top 10, SAST/DAST, least privilege, secrets management | `security_node` |

## LangGraph Flow

```
Human Request
    → PM Agent (requirements + stories)
    → Architect Agent (design + contracts)
    → Scrum Master (sprint planning + task breakdown)
    → [PARALLEL EXECUTION]
        ├── Backend Dev (APIs + logic)
        ├── Frontend Dev (UI + integration)
        ├── UI/UX Agent (design specs)
        ├── DevOps Agent (pipeline + IaC)
        └── Cloud Agent (infra provisioning)
    → QA Agent (test + validate ALL outputs)
    → Security Agent (scan + audit)
    → Scrum Master (sprint review + retro)
    → PM Agent (acceptance + next sprint)
```

## State Schema (LangGraph)

```python
from typing import TypedDict, List, Literal, Optional
from langgraph.graph import MessagesState

class AgileTeamState(TypedDict):
    # Human input
    request: str
    context: str

    # PM outputs
    user_stories: List[dict]
    acceptance_criteria: List[str]
    priority: Literal["critical", "high", "medium", "low"]

    # Architecture outputs
    architecture_decision: str
    api_contracts: List[dict]
    tech_stack: dict

    # Sprint state
    sprint_id: str
    sprint_tasks: List[dict]
    sprint_status: Literal["planning", "active", "review", "done"]
    blockers: List[str]

    # Dev outputs
    backend_code: dict
    frontend_code: dict
    design_specs: dict

    # Infra outputs
    infra_config: dict
    pipeline_config: dict
    cloud_resources: dict

    # Quality outputs
    test_results: dict
    security_scan: dict
    review_status: Literal["approved", "issues_found", "blocked"]

    # Control flow
    current_phase: str
    iteration_count: int
    human_escalation_needed: bool
```

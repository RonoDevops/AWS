# Skills Index — Agentic AI Team

> Each skill is a loadable, on-demand instruction set that an agent activates
> when its specific capability is needed. Skills are the HOW of the team.

## Skill Loading Protocol

```
When an agent needs a capability:
1. Identify the required skill from this index
2. Load the skill file into the agent's context
3. Follow the skill's protocol step-by-step
4. Produce output in the skill's specified format
5. Unload skill when task is complete (free context space)
```

## Complete Skill Registry

### Product Manager (`pm/`)

| Skill | File | Load When |
|-------|------|-----------|
| Requirements Extraction | `pm/requirements-extraction.md` | New feature request arrives, needs decomposition |
| User Story Writing | `pm/user-story-writing.md` | Requirements ready, need implementable stories |
| Sprint Acceptance | `pm/sprint-acceptance.md` | Sprint complete, deliverables need validation |

### Scrum Master (`scrum-master/`)

| Skill | File | Load When |
|-------|------|-----------|
| Sprint Planning | `scrum-master/sprint-planning.md` | Stories ready, need task breakdown + scheduling |
| Blocker Resolution | `scrum-master/blocker-resolution.md` | Agent reports BLOCKED or task stalls |
| Sprint Retrospective | `scrum-master/sprint-retrospective.md` | Sprint complete, need performance analysis |

### Architect (`architect/`)

| Skill | File | Load When |
|-------|------|-----------|
| System Design | `architect/system-design.md` | New feature needs architecture blueprint |
| ADR Writing | `architect/adr-writing.md` | Significant technical decision to document |
| API Contract Design | `architect/api-contract-design.md` | Services need interface definitions |

### Domain Expert (`domain-expert/`)

| Skill | File | Load When |
|-------|------|-----------|
| Domain Modeling | `domain-expert/domain-modeling.md` | New feature needs business concept mapping |
| Business Rule Validation | `domain-expert/business-rule-validation.md` | Code review for business logic correctness |

### Backend Developer (`backend-dev/`)

| Skill | File | Load When |
|-------|------|-----------|
| TDD Implementation | `backend-dev/tdd-implementation.md` | ANY backend coding task (always loaded) |
| API Implementation | `backend-dev/api-implementation.md` | Building REST endpoints from contracts |
| Database Design | `backend-dev/database-design.md` | New tables, migrations, or schema changes |

### Frontend Developer (`frontend-dev/`)

| Skill | File | Load When |
|-------|------|-----------|
| Component Development | `frontend-dev/component-development.md` | Building UI components from design specs |
| API Integration | `frontend-dev/api-integration.md` | Connecting frontend to backend APIs |

### UI/UX Agent (`uiux/`)

| Skill | File | Load When |
|-------|------|-----------|
| Design System | `uiux/design-system.md` | New project needs design foundation |
| User Flow Mapping | `uiux/user-flow-mapping.md` | Feature needs journey + interaction specs |

### QA Agent (`qa/`)

| Skill | File | Load When |
|-------|------|-----------|
| Test Plan Creation | `qa/test-plan-creation.md` | Feature needs comprehensive test strategy |
| Regression Testing | `qa/regression-testing.md` | Code changes need validation against existing tests |

### DevOps Agent (`devops/`)

| Skill | File | Load When |
|-------|------|-----------|
| CI/CD Pipeline | `devops/cicd-pipeline.md` | Project needs build/test/deploy automation |
| Infrastructure as Code | `devops/infrastructure-as-code.md` | Cloud infra needs provisioning via Terraform |

### Cloud Agent (`cloud/`)

| Skill | File | Load When |
|-------|------|-----------|
| AWS Service Selection | `cloud/aws-service-selection.md` | Workload needs cloud service decisions |
| Cost Optimization | `cloud/cost-optimization.md` | Monthly cost review or budget setup |

### Security Agent (`security/`)

| Skill | File | Load When |
|-------|------|-----------|
| Threat Modeling | `security/threat-modeling.md` | New external-facing feature designed |
| Code Security Review | `security/code-security-review.md` | Code changes need security audit |

## Skill Dependency Map

```
Feature Request arrives
    │
    ├─→ PM: requirements-extraction
    │     └─→ PM: user-story-writing
    │
    ├─→ Domain Expert: domain-modeling
    │
    ├─→ Architect: system-design
    │     ├─→ Architect: adr-writing (per decision)
    │     └─→ Architect: api-contract-design
    │
    ├─→ UI/UX: design-system (if new project)
    │     └─→ UI/UX: user-flow-mapping
    │
    ├─→ Scrum Master: sprint-planning
    │
    ├─→ [PARALLEL DEV PHASE]
    │     ├─→ Backend: tdd-implementation + api-implementation + database-design
    │     ├─→ Frontend: component-development + api-integration
    │     ├─→ DevOps: cicd-pipeline + infrastructure-as-code
    │     └─→ Cloud: aws-service-selection
    │
    ├─→ QA: test-plan-creation → qa: regression-testing
    │
    ├─→ Security: threat-modeling → security: code-security-review
    │
    ├─→ PM: sprint-acceptance
    │
    ├─→ Scrum Master: sprint-retrospective
    │
    └─→ Cloud: cost-optimization (monthly)
```

## Total: 20 Skills across 11 Agents

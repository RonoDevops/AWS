# Skill: CI/CD Pipeline Design & Implementation

> Load this skill when: A project needs automated build, test, and deployment
> pipelines. Covers GitHub Actions, Docker builds, and deployment automation.

## Context

In 100% AI development, the CI/CD pipeline is the ENFORCER. It runs every test,
every scan, every quality gate automatically. No agent can bypass it. No code
reaches production without passing every stage. The pipeline IS the process.

## CI/CD Pipeline Protocol

### Phase 1: Pipeline Architecture

```
PIPELINE STAGES:

┌─────────┐   ┌──────┐   ┌──────────┐   ┌───────┐   ┌─────────┐
│  LINT   │──→│ TEST │──→│ SECURITY │──→│ BUILD │──→│ DEPLOY  │
│         │   │      │   │  SCAN    │   │       │   │ STAGING │
└─────────┘   └──────┘   └──────────┘   └───────┘   └────┬────┘
                                                          │
                                                    ┌─────▼─────┐
                                                    │  SMOKE     │
                                                    │  TEST      │
                                                    └─────┬──────┘
                                                          │
                                                    ┌─────▼──────┐
                                                    │  DEPLOY    │
                                                    │  PRODUCTION│
                                                    │ (manual    │
                                                    │  approval) │
                                                    └─────┬──────┘
                                                          │
                                                    ┌─────▼──────┐
                                                    │  VERIFY    │
                                                    │  (health)  │
                                                    └────────────┘

PARALLEL EXECUTION:
  Lint + Test + Security Scan run IN PARALLEL (independent)
  Build runs AFTER all three pass
  Deploy runs AFTER build succeeds
```

### Phase 2: GitHub Actions Implementation

```yaml
# .github/workflows/ci-cd.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  PYTHON_VERSION: '3.12'
  NODE_VERSION: '20'
  DOCKER_REGISTRY: ${{ vars.AWS_ACCOUNT_ID }}.dkr.ecr.${{ vars.AWS_REGION }}.amazonaws.com
  IMAGE_NAME: ${{ github.event.repository.name }}

jobs:
  # ─── STAGE 1: Quality Checks (parallel) ───
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '${{ env.PYTHON_VERSION }}' }
      - run: pip install ruff mypy
      - run: ruff check .
      - run: ruff format --check .
      - run: mypy app/ --strict

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: test
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        ports: ['5432:5432']
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '${{ env.PYTHON_VERSION }}' }
      - run: pip install -r requirements.txt -r requirements-dev.txt
      - run: pytest tests/ -v --cov=app --cov-report=xml --junitxml=results.xml
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/test
      - uses: actions/upload-artifact@v4
        with: { name: coverage, path: coverage.xml }

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '${{ env.PYTHON_VERSION }}' }
      - run: pip install bandit safety
      - run: bandit -r app/ -f json -o bandit-report.json || true
      - run: safety check --json --output safety-report.json || true
      - run: |
          # Fail on critical/high findings
          python -c "
          import json
          with open('bandit-report.json') as f:
              results = json.load(f)
          high_issues = [r for r in results.get('results', [])
                        if r['issue_severity'] in ('HIGH', 'MEDIUM')]
          if high_issues:
              for issue in high_issues:
                  print(f'SECURITY: {issue[\"issue_severity\"]} - {issue[\"issue_text\"]} at {issue[\"filename\"]}:{issue[\"line_number\"]}')
              exit(1)
          print('Security scan clean')
          "

  # ─── STAGE 2: Build (after all checks pass) ───
  build:
    needs: [lint, test, security]
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4
      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.DOCKER_REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=
            type=ref,event=branch
      - uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.ref == 'refs/heads/main' }}
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ─── STAGE 3: Deploy Staging (auto on main) ───
  deploy-staging:
    if: github.ref == 'refs/heads/main'
    needs: [build]
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to staging
        run: |
          # Update ECS service with new image
          aws ecs update-service \
            --cluster staging \
            --service ${{ env.IMAGE_NAME }} \
            --force-new-deployment

      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster staging \
            --services ${{ env.IMAGE_NAME }}

      - name: Smoke test
        run: |
          STAGING_URL="${{ vars.STAGING_URL }}"
          # Health check
          curl -sf "$STAGING_URL/health" || exit 1
          echo "Staging deployment healthy"

  # ─── STAGE 4: Deploy Production (manual approval) ───
  deploy-production:
    needs: [deploy-staging]
    runs-on: ubuntu-latest
    environment: production  # Requires manual approval
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to production
        run: |
          aws ecs update-service \
            --cluster production \
            --service ${{ env.IMAGE_NAME }} \
            --force-new-deployment

      - name: Wait and verify
        run: |
          aws ecs wait services-stable \
            --cluster production \
            --services ${{ env.IMAGE_NAME }}
          curl -sf "${{ vars.PRODUCTION_URL }}/health" || exit 1
          echo "Production deployment healthy"
```

### Phase 3: Dockerfile Best Practices

```dockerfile
# Multi-stage build for minimal production image

# Stage 1: Build dependencies
FROM python:3.12-slim AS builder
WORKDIR /build
RUN pip install --no-cache-dir pip-tools
COPY requirements.in .
RUN pip-compile requirements.in -o requirements.txt
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Production runtime
FROM python:3.12-slim AS runtime
WORKDIR /app

# Security: non-root user
RUN groupadd -r app && useradd -r -g app -d /app -s /sbin/nologin app

# Copy only installed packages (not build tools)
COPY --from=builder /install /usr/local

# Copy application code
COPY app/ ./app/
COPY alembic/ ./alembic/
COPY alembic.ini .

# Security: read-only filesystem where possible
RUN chown -R app:app /app
USER app

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Phase 4: Pipeline Quality Gates

```
GATE DEFINITIONS:

LINT GATE:
  ✓ Zero linting errors (ruff)
  ✓ Zero formatting issues (ruff format)
  ✓ Zero type errors (mypy strict)
  → Fail = PR cannot merge

TEST GATE:
  ✓ All tests pass
  ✓ Coverage > 80% overall
  ✓ No test regressions (comparing to main)
  → Fail = PR cannot merge

SECURITY GATE:
  ✓ Zero critical vulnerabilities (bandit)
  ✓ Zero high vulnerabilities
  ✓ Zero critical dependency CVEs (safety)
  → Fail = PR cannot merge

BUILD GATE:
  ✓ Docker image builds successfully
  ✓ Image size < 500MB
  ✓ No secrets in image layers
  → Fail = Cannot deploy

STAGING GATE:
  ✓ Deployment succeeds
  ✓ Health check passes
  ✓ Smoke tests pass
  → Fail = Cannot promote to production

PRODUCTION GATE:
  ✓ Manual approval from environment protection rules
  ✓ Deployment succeeds
  ✓ Health check passes within 5 minutes
  ✓ Error rate < 1% for 10 minutes
  → Fail = Auto-rollback triggered
```

## Output Format

```json
{
  "task_id": "T-006-01",
  "status": "DONE",
  "deliverables": {
    "pipeline": ".github/workflows/ci-cd.yml",
    "dockerfile": "Dockerfile",
    "dockerignore": ".dockerignore"
  },
  "stages": 6,
  "quality_gates": 6,
  "environments": ["staging", "production"],
  "deployment_strategy": "rolling update with health checks",
  "estimated_pipeline_time": "~8 minutes (lint+test+security parallel)"
}
```

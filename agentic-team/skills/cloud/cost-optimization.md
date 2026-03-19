# Skill: Cloud Cost Optimization & FinOps

> Load this skill when: Cloud costs need review, budgets need setting, or
> infrastructure needs right-sizing after initial deployment.

## Context

In 100% AI development, AI agents don't naturally think about cost. They'll
provision the biggest instances, leave resources running 24/7, and never check
if a cheaper alternative exists. This skill forces systematic cost analysis
at every infrastructure decision point.

## Cost Optimization Protocol

### Phase 1: Cost Audit

```
AUDIT CHECKLIST — Run monthly:

COMPUTE:
  [ ] Are instances right-sized? (CPU < 40% avg → downsize)
  [ ] Are dev/staging environments running 24/7? (should be 10hrs/day)
  [ ] Are we using Graviton/ARM where possible? (20% savings)
  [ ] Are we using Spot for fault-tolerant workloads? (60-90% savings)
  [ ] Are Savings Plans in place for baseline compute? (30-40% savings)
  [ ] Are there idle/stopped instances still incurring charges?

DATABASE:
  [ ] Is RDS right-sized? (CPU < 30% avg → downsize)
  [ ] Is Aurora Serverless v2 appropriate? (variable load)
  [ ] Are read replicas needed or wasted?
  [ ] Is storage auto-scaling set with reasonable limits?
  [ ] Are backups retained longer than needed?

STORAGE:
  [ ] S3 lifecycle policies configured? (IA after 30d, Glacier after 90d)
  [ ] S3 Intelligent Tiering for unknown access patterns?
  [ ] Are there orphaned EBS volumes?
  [ ] Are old snapshots being cleaned up?

NETWORKING:
  [ ] NAT Gateway — do we need it in all AZs? ($32/month each)
  [ ] Data transfer — are we routing through CloudFront? (cheaper than direct)
  [ ] VPC endpoints for S3/DynamoDB? (eliminates NAT charges for AWS traffic)

MONITORING:
  [ ] CloudWatch log retention — is 30 days sufficient? (reduce to 7 for dev)
  [ ] Are we paying for unused custom metrics?
  [ ] Are detailed monitoring metrics needed or is basic sufficient?
```

### Phase 2: Right-Sizing Analysis

```
INSTANCE RIGHT-SIZING:

Current: t3.large (2 vCPU, 8 GB) — $0.0832/hr = $60.74/month
Metrics (30-day average):
  CPU:    18% avg, 45% peak
  Memory: 32% avg, 55% peak

RECOMMENDATION:
  Downsize to: t3.medium (2 vCPU, 4 GB) — $0.0416/hr = $30.37/month
  Savings: $30.37/month (50%)

  OR with Graviton:
  t4g.medium (2 vCPU, 4 GB) — $0.0336/hr = $24.53/month
  Savings: $36.21/month (60%)

SAFETY CHECK:
  [ ] Peak CPU stays below 70% on smaller instance
  [ ] Peak memory stays below 80% on smaller instance
  [ ] Performance tests pass on smaller instance
  [ ] Rollback plan: scale back up if issues detected
```

### Phase 3: Savings Plan Calculator

```
SAVINGS PLAN ANALYSIS:

Current monthly on-demand spend: $800/month compute

OPTION A: No commitment (on-demand)
  Monthly: $800
  Annual: $9,600

OPTION B: 1-year Compute Savings Plan (no upfront)
  Monthly: $560 (30% discount)
  Annual: $6,720
  Savings: $2,880/year

OPTION C: 1-year Compute Savings Plan (all upfront)
  Upfront: $6,048
  Monthly: $0
  Annual: $6,048
  Savings: $3,552/year

OPTION D: 3-year Compute Savings Plan (no upfront)
  Monthly: $448 (44% discount)
  Annual: $5,376
  Savings: $4,224/year

RECOMMENDATION: Option B (1-year, no upfront)
  Reason: Good savings (30%) with flexibility to adjust after 1 year.
  Risk: Low — baseline compute is predictable.
  Break-even: If we use > 70% of committed amount.
```

### Phase 4: Budget Alerts

```hcl
# Terraform budget configuration

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 50
    threshold_type      = "PERCENTAGE"
    notification_type   = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 80
    threshold_type      = "PERCENTAGE"
    notification_type   = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 100
    threshold_type      = "PERCENTAGE"
    notification_type   = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  # Forecast alert — warns before you hit the limit
  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 100
    threshold_type      = "PERCENTAGE"
    notification_type   = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
  }
}

# BUDGET LEVELS:
# Dev:     $200/month
# Staging: $400/month
# Prod:    $800/month
# Total:   $1,400/month with 10% buffer = $1,540
```

### Phase 5: Dev/Staging Cost Reduction

```
DEV ENVIRONMENT SCHEDULE (save 60%):
  Run: 8am - 6pm weekdays (10 hrs × 5 days = 50 hrs/week)
  Stop: Nights and weekends (118 hrs/week)
  Savings: 70% reduction in compute costs

  Implementation:
    - Lambda function triggered by EventBridge schedule
    - Scale ECS desired count to 0 at 6pm
    - Scale ECS desired count to 1 at 8am
    - RDS: Stop instance (auto-restarts after 7 days — re-stop via Lambda)

STAGING ENVIRONMENT:
  Run: 24/7 (mirrors production for realistic testing)
  But: Use smallest viable instance sizes
  And: No multi-AZ (single AZ is fine for staging)
  Savings: 40% vs production-equivalent sizing
```

## Output Format

```json
{
  "audit_date": "2026-03-19",
  "current_monthly_cost": "$1,200",
  "optimized_monthly_cost": "$780",
  "savings": "$420/month ($5,040/year)",
  "recommendations": [
    {
      "action": "Right-size prod compute to t4g.medium",
      "savings": "$36/month",
      "risk": "low",
      "effort": "S"
    },
    {
      "action": "Schedule dev environment (10hrs/day weekdays)",
      "savings": "$120/month",
      "risk": "none",
      "effort": "M"
    },
    {
      "action": "1-year Compute Savings Plan (no upfront)",
      "savings": "$240/month",
      "risk": "low",
      "effort": "S"
    },
    {
      "action": "Add S3 lifecycle policies",
      "savings": "$24/month",
      "risk": "none",
      "effort": "S"
    }
  ],
  "budget_alerts_configured": true
}
```

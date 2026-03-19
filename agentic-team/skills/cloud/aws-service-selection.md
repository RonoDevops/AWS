# Skill: AWS Service Selection & Provisioning

> Load this skill when: A workload needs cloud infrastructure and the right AWS
> services must be selected based on requirements, cost, and scalability.

## Context

In 100% AI development, cloud decisions are irreversible without significant cost.
Choose wrong and you waste weeks migrating. This skill provides a systematic
framework for selecting AWS services that match the workload's actual needs —
not the most exciting or newest service, but the RIGHT one.

## Service Selection Protocol

### Phase 1: Workload Classification

```
CLASSIFY YOUR WORKLOAD:

REQUEST PATTERN:
  □ Synchronous (user waits for response)      → API Gateway + Compute
  □ Asynchronous (fire-and-forget)              → SQS/SNS + Lambda/ECS
  □ Event-driven (react to state changes)       → EventBridge + Lambda
  □ Batch (process large datasets)              → Step Functions + Batch/EMR
  □ Real-time streaming (continuous data flow)  → Kinesis + Lambda/ECS
  □ Scheduled (cron jobs)                       → EventBridge Scheduler + Lambda

COMPUTE DECISION TREE:
  How long does the function run?
    < 15 minutes, < 10GB memory       → Lambda (serverless)
    < 15 minutes, needs GPU            → Lambda (not suitable) → ECS/EC2
    > 15 minutes, stateless            → ECS Fargate
    > 15 minutes, needs local storage  → ECS on EC2
    Long-running, stateful             → EC2 or EKS

  How many requests per second?
    < 100 req/s, bursty     → Lambda (scale to zero)
    100-10,000 req/s        → ECS Fargate (auto-scaling)
    > 10,000 req/s          → ECS on EC2 or EKS (cost optimization)

DATABASE DECISION TREE:
  Data model?
    Relational + complex queries + transactions  → RDS (Aurora PostgreSQL)
    Key-value + high throughput + simple queries  → DynamoDB
    Document store + flexible schema             → DocumentDB or DynamoDB
    Graph relationships                          → Neptune
    Time-series data                             → Timestream
    Search + full-text + analytics               → OpenSearch

  Scale?
    < 100GB, moderate traffic    → RDS (single instance)
    100GB-10TB, high read        → RDS + Read Replicas or Aurora
    > 10TB or extreme write      → DynamoDB or Aurora Serverless v2
    Unpredictable / spiky        → Aurora Serverless v2 or DynamoDB on-demand

STORAGE DECISION TREE:
  Access pattern?
    Frequent access (< 30 days)     → S3 Standard
    Infrequent (30-90 days)         → S3 Infrequent Access
    Archive (> 90 days)             → S3 Glacier Instant/Flexible
    Shared filesystem               → EFS
    High-performance filesystem     → FSx for Lustre
    Block storage for EC2           → EBS (gp3)

MESSAGING DECISION TREE:
  Pattern?
    Queue (1 consumer)              → SQS Standard
    Queue (ordered, exactly-once)   → SQS FIFO
    Fan-out (many consumers)        → SNS → SQS
    Event routing (rules-based)     → EventBridge
    Stream processing               → Kinesis Data Streams
```

### Phase 2: Service Configuration Matrix

```
SERVICE: ECS Fargate (example)

CONFIGURATION CHECKLIST:
  Compute:
    [ ] CPU: 256 | 512 | 1024 | 2048 | 4096
    [ ] Memory: (varies by CPU — see compatibility matrix)
    [ ] Architecture: x86_64 | ARM64 (Graviton = 20% cheaper)

  Networking:
    [ ] VPC + Private subnets (NEVER public for application containers)
    [ ] Security group: ingress from ALB only, egress to VPC + internet
    [ ] Service discovery: Cloud Map (for service-to-service)

  Scaling:
    [ ] Min tasks: 2 (for HA in production)
    [ ] Max tasks: 10 (adjust based on load testing)
    [ ] Scaling metric: CPU > 70% OR request count per target
    [ ] Scale-out cooldown: 60s (react quickly)
    [ ] Scale-in cooldown: 300s (avoid flapping)

  Reliability:
    [ ] Multi-AZ: YES (spread across subnets)
    [ ] Health check: HTTP /health, interval 30s, threshold 3
    [ ] Circuit breaker: ENABLED with rollback
    [ ] Deployment: minimum healthy 100%, maximum 200%

  Observability:
    [ ] Logs: CloudWatch Logs (7-day retention dev, 30-day prod)
    [ ] Metrics: Container Insights ENABLED
    [ ] Traces: X-Ray SDK integrated
    [ ] Alarms: CPU > 85%, memory > 85%, 5xx > 1%

  Cost Optimization:
    [ ] Graviton (ARM64): 20% cheaper than x86
    [ ] Spot capacity: for dev/staging (not prod)
    [ ] Right-size: start small, scale up based on metrics
    [ ] Savings Plans: for predictable prod baseline
```

### Phase 3: Cost Estimation Template

```
MONTHLY COST ESTIMATE:

SERVICE: ECS Fargate
  Compute:
    Tasks: 3 (production baseline)
    CPU: 0.5 vCPU × $0.04048/hr = $0.06/hr per task
    Memory: 1 GB × $0.004445/hr = $0.004/hr per task
    Monthly: 3 tasks × $0.064/hr × 730 hrs = $140.16

  Auto-scaling overhead (estimated 20% extra):
    $140.16 × 0.2 = $28.03

SERVICE: RDS Aurora PostgreSQL
  Instance: db.t4g.medium (2 vCPU, 4 GB)
    On-demand: $0.073/hr × 730 hrs = $53.29
    Multi-AZ: $53.29 × 2 = $106.58
  Storage: 50 GB × $0.10/GB = $5.00
  I/O: 1M requests × $0.20/M = $0.20
  Backups: 50 GB × $0.021/GB = $1.05
  Subtotal: $112.83

SERVICE: Application Load Balancer
  Fixed: $0.0225/hr × 730 hrs = $16.43
  LCU: ~5 LCU × $0.008/hr × 730 hrs = $29.20
  Subtotal: $45.63

SERVICE: S3 (static assets + uploads)
  Storage: 10 GB × $0.023/GB = $0.23
  Requests: 100K GET × $0.0004/1K = $0.04
  Subtotal: $0.27

SERVICE: CloudWatch
  Logs: 5 GB ingestion × $0.50/GB = $2.50
  Metrics: 20 custom × $0.30 = $6.00
  Alarms: 10 × $0.10 = $1.00
  Subtotal: $9.50

─────────────────────────────────
TOTAL ESTIMATED: $336.42/month
─────────────────────────────────

COST OPTIMIZATION RECOMMENDATIONS:
  1. Use Graviton (ARM64): save ~$28/month on compute
  2. Reserved Instance for RDS: save ~$35/month (1-year)
  3. S3 Intelligent Tiering: save on infrequent access data
  4. Review CloudWatch log retention: reduce if 7 days sufficient
```

### Phase 4: Well-Architected Checklist

```
FOR EVERY DEPLOYMENT, VERIFY:

SECURITY:
  [ ] IAM roles use least privilege (no * permissions)
  [ ] Secrets in AWS Secrets Manager (not env vars)
  [ ] Encryption at rest (KMS for RDS, S3, EBS)
  [ ] Encryption in transit (TLS 1.2+ everywhere)
  [ ] VPC: databases in private subnets
  [ ] WAF on public-facing ALB
  [ ] GuardDuty enabled
  [ ] CloudTrail enabled

RELIABILITY:
  [ ] Multi-AZ for all production services
  [ ] Auto-scaling configured with appropriate thresholds
  [ ] Health checks on all services
  [ ] Automated backups with tested restore procedure
  [ ] Circuit breakers on external calls

PERFORMANCE:
  [ ] Right-sized instances (not over-provisioned)
  [ ] Caching layer where appropriate (ElastiCache/CloudFront)
  [ ] Connection pooling for databases (RDS Proxy)
  [ ] CDN for static assets

COST:
  [ ] Budget alerts at 50%, 80%, 100%
  [ ] Savings Plans for baseline compute
  [ ] S3 lifecycle policies
  [ ] Unused resources identified and terminated
  [ ] Cost allocation tags on all resources
```

## Output Format

```json
{
  "task_id": "T-007-01",
  "status": "DONE",
  "services_selected": {
    "compute": "ECS Fargate (ARM64/Graviton)",
    "database": "Aurora PostgreSQL Serverless v2",
    "storage": "S3 Standard + Intelligent Tiering",
    "messaging": "SQS Standard",
    "cdn": "CloudFront",
    "monitoring": "CloudWatch + X-Ray"
  },
  "estimated_monthly_cost": {
    "dev": "$85",
    "staging": "$180",
    "production": "$340"
  },
  "well_architected_score": "5/6 pillars addressed",
  "terraform_modules_needed": ["networking", "compute", "database", "storage", "monitoring"]
}
```

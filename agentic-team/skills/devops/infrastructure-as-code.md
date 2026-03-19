# Skill: Infrastructure as Code (Terraform)

> Load this skill when: Cloud infrastructure needs to be provisioned, modified,
> or documented. Covers Terraform module design, state management, and environments.

## Context

In 100% AI development, infrastructure is CODE — versioned, reviewed, tested,
and reproducible. No clicking in the AWS console. No undocumented resources.
If it's not in Terraform, it doesn't exist. Every resource is tagged, every
change is tracked, every environment is identical except for scale.

## IaC Protocol

### Phase 1: Module Architecture

```
infra/
├── modules/                    # Reusable modules
│   ├── networking/
│   │   ├── main.tf            # VPC, subnets, security groups
│   │   ├── variables.tf       # Input variables
│   │   ├── outputs.tf         # Output values
│   │   └── README.md          # Module documentation
│   ├── compute/
│   │   ├── main.tf            # ECS cluster, task definitions, services
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── iam.tf             # IAM roles and policies
│   ├── database/
│   │   ├── main.tf            # RDS instance, parameter groups
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── storage/
│   │   ├── main.tf            # S3 buckets, lifecycle rules
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── monitoring/
│       ├── main.tf            # CloudWatch dashboards, alarms
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/               # Environment-specific configuration
│   ├── dev/
│   │   ├── main.tf            # Module composition
│   │   ├── terraform.tfvars   # Dev-specific values
│   │   └── backend.tf         # State storage config
│   ├── staging/
│   │   ├── main.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── prod/
│       ├── main.tf
│       ├── terraform.tfvars
│       └── backend.tf
│
└── global/                     # Shared resources (IAM, DNS, etc.)
    ├── main.tf
    ├── variables.tf
    └── backend.tf
```

### Phase 2: Module Implementation Template

```hcl
# modules/compute/main.tf

# ─── ECS Cluster ───
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

# ─── Task Definition ───
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project}-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.project
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        for k, v in var.environment_variables : {
          name  = k
          value = v
        }
      ]

      secrets = [
        for k, v in var.secrets : {
          name      = k
          valueFrom = v
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.tags
}

# ─── ECS Service ───
resource "aws_ecs_service" "app" {
  name            = var.project
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.project
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  tags = local.tags
}

# ─── Auto Scaling ───
resource "aws_appautoscaling_target" "app" {
  max_capacity       = var.max_count
  min_capacity       = var.min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.project}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.app.resource_id
  scalable_dimension = aws_appautoscaling_target.app.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ─── Locals ───
locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

### Phase 3: Tagging Standard

```hcl
# EVERY resource gets these tags:
tags = {
  Project     = var.project          # "myapp"
  Environment = var.environment      # "dev" | "staging" | "prod"
  ManagedBy   = "terraform"          # Always "terraform"
  Team        = var.team             # "platform" | "backend"
  CostCenter  = var.cost_center      # For billing allocation
}

# NO UNTAGGED RESOURCES — enforce with AWS Config rules
```

### Phase 4: State Management

```hcl
# backend.tf — Remote state with locking

terraform {
  backend "s3" {
    bucket         = "myapp-terraform-state"
    key            = "environments/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# STATE RULES:
# 1. NEVER store state locally in production
# 2. ALWAYS enable encryption
# 3. ALWAYS enable state locking (DynamoDB)
# 4. Each environment has its own state file
# 5. NEVER manually edit state — use terraform state commands
# 6. State contains secrets — restrict S3 bucket access
```

### Phase 5: Environment Parity

```hcl
# environments/dev/terraform.tfvars
environment    = "dev"
instance_type  = "t3.micro"
desired_count  = 1
min_count      = 1
max_count      = 2
db_instance    = "db.t4g.micro"
multi_az       = false

# environments/staging/terraform.tfvars
environment    = "staging"
instance_type  = "t3.small"
desired_count  = 2
min_count      = 2
max_count      = 4
db_instance    = "db.t4g.small"
multi_az       = true

# environments/prod/terraform.tfvars
environment    = "prod"
instance_type  = "t3.medium"
desired_count  = 3
min_count      = 3
max_count      = 10
db_instance    = "db.t4g.medium"
multi_az       = true

# SAME modules, SAME structure, DIFFERENT scale.
# The only difference is the .tfvars file.
```

## Output Format

```json
{
  "task_id": "T-003-01",
  "status": "DONE",
  "modules_created": ["networking", "compute", "database", "monitoring"],
  "environments": ["dev", "staging", "prod"],
  "resources_provisioned": {
    "vpc": 1, "subnets": 4, "security_groups": 3,
    "ecs_cluster": 1, "ecs_service": 1,
    "rds_instance": 1, "s3_bucket": 2,
    "cloudwatch_alarms": 5
  },
  "state_backend": "s3 + dynamodb locking",
  "estimated_cost": "$180/month (dev), $350/month (staging), $600/month (prod)"
}
```

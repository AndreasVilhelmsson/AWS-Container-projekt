#############################################
# ECS: Log group, IAM-roller, Cluster, Task def, Service
#############################################

# CloudWatch Logs (håll nere retention)
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 14
}

# Execution role (drar image från ECR, skriver CW-logs)
resource "aws_iam_role" "exec" {
  name = "${var.app_name}-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "exec_attach" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# (valfritt) egen policy för ECR pull + logs (du har ovan via managed policy)

# Task role (permissions för appen – lämna tom tills du behöver AWS-API)
resource "aws_iam_role" "task" {
  name = "${var.app_name}-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "${var.app_name}-cluster"
}

# Task definition – tvinga X86_64 så vi matchar --platform linux/amd64
resource "aws_ecs_task_definition" "this" {
  family                   = var.app_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu    # 256
  memory                   = var.memory # 512
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "web"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [
        { containerPort = var.container_port, hostPort = var.container_port, protocol = "tcp" }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = var.app_name
        }
      }
      # Inbyggd container healthcheck (valfritt – ALB räcker oftast)
      # healthCheck = {
      #   command     = ["CMD-SHELL", "wget -qO- http://127.0.0.1:${var.container_port}/index.html || exit 1"],
      #   interval    = 30,
      #   timeout     = 5,
      #   retries     = 3,
      #   startPeriod = 10
      # }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "this" {
  name            = "${var.app_name}-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Nyckeln som räddade oss i felsökningen:
  health_check_grace_period_seconds = 30

  # Rolling update
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true # viktigt i public subnets
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "web"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]
}

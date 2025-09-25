#############################################
# ALB + SG + Target group + Listener
#############################################

# Security Group för ALB (öppen mot världen på 80)
resource "aws_security_group" "alb" {
  name        = "${var.app_name}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group för ECS-tasks (tillåter bara trafik från ALB)
resource "aws_security_group" "tasks" {
  name        = "${var.app_name}-tasks-sg"
  description = "ECS tasks security group"
  vpc_id      = var.vpc_id

  # Trafik till containerporten endast från ALB
  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Själva ALB:en
resource "aws_lb" "this" {
  name               = "${var.app_name}-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
}

# Target Group med robust health check för SPA/React + snabbare drain
resource "aws_lb_target_group" "this" {
  name        = "${var.app_name}-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  # Hälso-kontroll: peka på index.html (bättre för SPA än "/")
  health_check {
    path                = var.health_check_path # default "/index.html"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # Gör omdränering snabbare (default 300s). Stöds av de flesta prov.versioner.
  # Om din provider-version klagar, kommentera raden nedan.
  deregistration_delay = 60
}

# HTTP listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

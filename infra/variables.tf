variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "app_name" {
  type    = string
  default = "react-web"
}

variable "vpc_id" {
  description = "VPC där ALB/ECS körs"
  type        = string
}

variable "public_subnet_ids" {
  description = "Publika subnät (minst 2 AZ) för ALB/ECS"
  type        = list(string)
}

# Container/ECS
variable "container_port" {
  type    = number
  default = 80
}

variable "cpu" {
  type    = number
  default = 256
} # 0.25 vCPU

variable "memory" {
  type    = number
  default = 512
} # MB

variable "desired_count" {
  type    = number
  default = 2
}

variable "min_capacity" {
  description = "Minsta antal Fargate-tasks vid autoskalning"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Högsta antal Fargate-tasks vid autoskalning"
  type        = number
  default     = 4
}

variable "cpu_target_value" {
  description = "Mål-värde för genomsnittlig CPU-utilisation (%)"
  type        = number
  default     = 50
}
variable "health_check_path" {
  type    = string
  default = "/index.html"
}

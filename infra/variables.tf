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
variable "health_check_path" {
  type    = string
  default = "/index.html"
}

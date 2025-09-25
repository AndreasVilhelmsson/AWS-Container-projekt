terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_ecr_repository" "app" {
  name = var.app_name

  image_scanning_configuration { scan_on_push = true }
  # gör det lätt att städa i labb; ta bort i prod om du vill behålla bilder
  force_delete = true
}
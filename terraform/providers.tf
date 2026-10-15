terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # La "libreta de apuntes" de Terraform vive en S3, no en tu Codespace
  backend "s3" {
    bucket       = "taller5-tfstate-478400396947"
    key          = "taller5/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  # Estas etiquetas se ponen solas en todos los recursos
  default_tags {
    tags = {
      Equipo   = var.team
      Proyecto = var.project
      Ambiente = var.environment
    }
  }
}

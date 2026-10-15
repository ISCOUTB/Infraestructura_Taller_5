data "aws_caller_identity" "current" {}

locals {
  bucket_name = "taller5-archivos-${data.aws_caller_identity.current.account_id}"
}

# ---------- Bodega de archivos (S3) ----------
resource "aws_s3_bucket" "archivos" {
  bucket        = local.bucket_name
  force_destroy = true # permite destruir el bucket aunque tenga archivos
}

# Nadie de internet puede ver los archivos
resource "aws_s3_bucket_public_access_block" "archivos" {
  bucket                  = aws_s3_bucket.archivos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "archivos" {
  bucket = aws_s3_bucket.archivos.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archivos" {
  bucket = aws_s3_bucket.archivos.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------- Limpieza automática del bucket ----------
resource "aws_s3_bucket_lifecycle_configuration" "archivos" {
  bucket = aws_s3_bucket.archivos.id

  rule {
    id     = "limpieza"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ---------- Almacén de imágenes Docker (ECR) ----------
resource "aws_ecr_repository" "app" {
  name                 = "taller5-app"
  image_tag_mutability = "IMMUTABLE" # una versión publicada no se puede sobrescribir
  force_delete         = true        # permite destruirlo aunque tenga imágenes

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Límite de costos: solo guarda las 5 imágenes más recientes
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conservar solo las 5 imagenes mas recientes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

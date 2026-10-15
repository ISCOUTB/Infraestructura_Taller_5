# ---------- Red: usamos la VPC por defecto (más simple y sin costo extra) ----------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Sistema operativo más reciente de Amazon Linux 2023
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------- Firewall: solo el puerto web ----------
resource "aws_security_group" "app" {
  name        = "taller5-app-sg"
  description = "Permite trafico web (HTTP) hacia la app del taller 5"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP publico para probar la API"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Salida a internet (descargar imagen, hablar con AWS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- Carné de la máquina (rol con permisos mínimos) ----------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "taller5-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Solo puede leer/escribir en ESTE bucket
data "aws_iam_policy_document" "app_s3" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.archivos.arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.archivos.arn}/*"]
  }
}

resource "aws_iam_role_policy" "app_s3" {
  name   = "taller5-app-s3-minimo"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_s3.json
}

# Solo puede DESCARGAR imágenes de ESTE repositorio ECR
data "aws_iam_policy_document" "app_ecr" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "app_ecr" {
  name   = "taller5-app-ecr-lectura"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_ecr.json
}

# Permite que GitHub Actions le ordene desplegar vía SSM (sin abrir SSH)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = "taller5-app-profile"
  role = aws_iam_role.app.name
}

# ---------- La máquina ----------
locals {
  registry  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  image_uri = aws_ecr_repository.app.repository_url

  user_data = <<EOT
#!/bin/bash
set -e
dnf install -y docker
systemctl enable --now docker

# Script de despliegue: GitHub Actions lo ejecuta con la versión de la imagen
cat > /usr/local/bin/deploy.sh <<'DEPLOY'
#!/bin/bash
set -euo pipefail
TAG="$1"
aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.registry}
docker pull ${local.image_uri}:$TAG
docker rm -f app 2>/dev/null || true
docker run -d --name app --restart unless-stopped -p 80:8000 \
  -e BUCKET_NAME=${aws_s3_bucket.archivos.id} \
  -e AWS_REGION=${var.aws_region} \
  ${local.image_uri}:$TAG
DEPLOY
chmod +x /usr/local/bin/deploy.sh
EOT
}

resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.ami.value
  instance_type               = var.instance_type
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.app.name
  associate_public_ip_address = true
  monitoring                  = true
  ebs_optimized               = true
  user_data                   = local.user_data

  # IMDSv2 obligatorio; hop limit 2 para que el contenedor también reciba el rol
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size = 8 # límite de costos: disco pequeño
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "taller5-app"
  }
}

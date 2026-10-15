output "app_url" {
  description = "URL pública de la app (probar /health y /files)"
  value       = "http://${aws_instance.app.public_ip}"
}

output "bucket_name" {
  description = "Bucket S3 donde se guardan los archivos"
  value       = aws_s3_bucket.archivos.id
}

output "ecr_repository_url" {
  description = "Repositorio ECR donde GitHub Actions publica la imagen"
  value       = aws_ecr_repository.app.repository_url
}

output "instance_id" {
  description = "ID de la máquina EC2 (la usa el workflow para desplegar vía SSM)"
  value       = aws_instance.app.id
}

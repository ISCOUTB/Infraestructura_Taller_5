variable "aws_region" {
  description = "Región de AWS donde se despliega todo"
  type        = string
  default     = "us-east-1"
}

variable "team" {
  description = "Nombre del equipo (etiqueta Equipo)"
  type        = string
  default     = "equipo-proyectoTIUTB"
}

variable "project" {
  description = "Nombre del proyecto (etiqueta Proyecto)"
  type        = string
  default     = "taller5-almacenamiento"
}

variable "environment" {
  description = "Ambiente de despliegue (etiqueta Ambiente)"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "Tamaño de la máquina EC2. Pequeña a propósito, para controlar costos"
  type        = string
  default     = "t3.micro"
}

variable "image_tag" {
  description = "Versión de la imagen Docker a desplegar (la pone GitHub Actions)"
  type        = string
  default     = "latest"
}

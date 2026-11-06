variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefix for resource names."
  type        = string
  default     = "tsn"
}

variable "my_ip_cidr" {
  description = "Your public IP as x.x.x.x/32, allowed to reach PostgreSQL with psql. Set with TF_VAR_my_ip_cidr."
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class (smallest Graviton class that runs pgvector)."
  type        = string
  default     = "db.t4g.micro"
}

variable "allowed_origins" {
  description = "Web origins allowed to upload with presigned URLs (CORS)."
  type        = list(string)
  default     = ["http://localhost:5173"]
}

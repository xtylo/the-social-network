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
  # Phases 2 and 3 were measured on db.t4g.micro (2 vCPU, 1 GB, ~80 max connections).
  # Larger classes (e.g. db.t4g.xlarge) are rejected on AWS Free plan accounts; db.t4g.small was not tested.
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allowed_origins" {
  description = "Web origins allowed to upload with presigned URLs (CORS)."
  type        = list(string)
  default     = ["http://localhost:5173"]
}

variable "reco_reserved_concurrency" {
  description = "Max concurrent instances of the Rust Lambda. Caps database connections and prevents connection storms."
  type        = number
  default     = 60 # phase 2: 25; phase 3: 60 (fits the ~80 connections of db.t4g.micro)
}

variable "api_rate_limit" {
  description = "API Gateway steady-state limit (req/s) for the stage. Phase 2 used 300."
  type        = number
  default     = 3000
}

variable "api_burst_limit" {
  description = "API Gateway burst limit (requests) for the stage. Phase 2 used 500."
  type        = number
  default     = 5000
}

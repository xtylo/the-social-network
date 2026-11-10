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
  # Phase 2: db.t4g.micro (2 vCPU, 1 GB, ~80 max connections). Phase 3: db.t4g.small (2 vCPU, 2 GB) so 100 Lambda
  # connections fit. Larger classes (e.g. db.t4g.xlarge) are rejected on AWS Free plan accounts.
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.small"
}

variable "allowed_origins" {
  description = "Web origins allowed to upload with presigned URLs (CORS)."
  type        = list(string)
  default     = ["http://localhost:5173"]
}

variable "reco_reserved_concurrency" {
  description = "Max concurrent instances of the Rust Lambda. Caps database connections and prevents connection storms."
  type        = number
  default     = 100 # phase 2 used 25; 2,000 req/s x ~20 ms is about 40 concurrent instances
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

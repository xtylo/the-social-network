# Real AWS deployment (phase 2). The local Floci setup lives in ../main.tf.
# Run from a terminal prepared with `source scripts/aws-env.sh` (it removes the Floci endpoint).

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region

  # Every resource gets these tags, so they are easy to find (and to confirm deleted) in the console.
  default_tags {
    tags = {
      Project   = "the-social-network"
      ManagedBy = "terraform"
    }
  }
}

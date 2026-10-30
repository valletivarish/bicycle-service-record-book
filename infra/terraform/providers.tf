terraform {
  required_version = ">= 1.10"

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.7" }
  }

  # The state bucket is made once per lab account by scripts/bootstrap-state.sh
  # and passed with -backend-config="bucket=...". S3 lock files replace DynamoDB.
  backend "s3" {
    key          = "service-book/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = { Application = "service-book", ManagedBy = "terraform" }
  }
}

#!/bin/bash
# Run once per lab account before the first terraform init. Creates the
# private, versioned S3 bucket that holds the Terraform state. It is made here
# because the AWS Academy policy blocks a read that Terraform's aws_s3_bucket
# resource needs, and the state bucket cannot be managed by its own state.
set -euo pipefail
REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --region $REGION --query Account --output text)
BUCKET="$ACCOUNT_ID-servicebook-tfstate"

if ! aws s3api head-bucket --region $REGION --bucket "$BUCKET" 2>/dev/null; then
  aws s3api create-bucket --region $REGION --bucket "$BUCKET"
fi
aws s3api put-public-access-block --region $REGION --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-versioning --region $REGION --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
echo "ready: $BUCKET"

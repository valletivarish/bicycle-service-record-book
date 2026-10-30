#!/bin/bash
# Run once per lab account before the first terraform init. Creates two
# private buckets: Terraform state and the Angular build behind CloudFront.
# They are made here because the AWS Academy policy blocks a read that
# Terraform's aws_s3_bucket resource needs.
set -euo pipefail
REGION=us-east-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

for bucket in "$ACCOUNT_ID-servicebook-tfstate" "$ACCOUNT_ID-servicebook-web"; do
  if ! aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    aws s3api create-bucket --bucket "$bucket" --region "$REGION"
  fi
  aws s3api put-public-access-block --bucket "$bucket" --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  echo "ready: $bucket"
done
# State history lets a broken apply be recovered.
aws s3api put-bucket-versioning --bucket "$ACCOUNT_ID-servicebook-tfstate" \
  --versioning-configuration Status=Enabled

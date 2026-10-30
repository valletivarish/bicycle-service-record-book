output "app_url" {
  value = "https://${aws_cloudfront_distribution.app.domain_name}"
}

output "distribution_id" {
  value = aws_cloudfront_distribution.app.id
}

output "site_bucket" {
  value = local.site_bucket
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "instance_id" {
  value = aws_instance.api.id
}

output "api_host_ip" {
  value = aws_eip.api.public_ip
}

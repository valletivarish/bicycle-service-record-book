output "app_url" {
  value = "http://${aws_eip.api.public_ip}"
}

output "registry" {
  value = split("/", aws_ecr_repository.app["service-book-api"].repository_url)[0]
}

output "instance_id" {
  value = aws_instance.api.id
}

output "api_host_ip" {
  value = aws_eip.api.public_ip
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

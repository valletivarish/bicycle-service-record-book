data "aws_caller_identity" "current" {}

# The bucket itself is created by scripts/bootstrap-state.sh because the AWS
# Academy policy denies a read (object lock configuration) that the
# aws_s3_bucket resource always performs. Its settings are managed here.
locals {
  site_bucket = "${data.aws_caller_identity.current.account_id}-servicebook-web"
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = local.site_bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "service-book-site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Only this distribution may read the bucket; the bucket stays private.
resource "aws_s3_bucket_policy" "site" {
  bucket = local.site_bucket
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "CloudFrontRead"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "arn:aws:s3:::${local.site_bucket}/*"
      Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.app.arn } }
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.site]
}

# Angular routes like /records/12 have no file in S3. This viewer-request
# function sends them to index.html. It is attached to the S3 behaviour only,
# so a 404 from the API stays a JSON 404 instead of becoming index.html.
resource "aws_cloudfront_function" "spa_routes" {
  name    = "service-book-spa-routes"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-JS
    function handler(event) {
      var request = event.request;
      if (!request.uri.includes('.')) {
        request.uri = '/index.html';
      }
      return request;
    }
  JS
}

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_distribution" "app" {
  enabled             = true
  comment             = "Service record book"
  default_root_object = "index.html"
  # Europe and North America edges only: the users are one Irish desk, and
  # fewer edge locations is the cheapest price class.
  price_class = "PriceClass_100"

  origin {
    origin_id                = "site"
    domain_name              = "${local.site_bucket}.s3.${var.region}.amazonaws.com"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  # The EC2 origin has no TLS certificate, so CloudFront talks to Nginx over
  # HTTP; browsers still only ever see HTTPS on the CloudFront domain.
  origin {
    origin_id   = "api"
    domain_name = aws_eip.api.public_dns

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "site"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id
    compress               = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_routes.arn
    }
  }

  # CRUD responses are never cached; every method and query string is passed on.
  ordered_cache_behavior {
    path_pattern             = "/api/*"
    target_origin_id         = "api"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

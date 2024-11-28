resource "aws_s3_bucket" "s3_static_website" {
  bucket = var.bucket_name

  tags = {
    Name = "s3-static-website"
  }
}

resource "aws_s3_bucket_public_access_block" "site_bucket_public_access" {
  bucket = aws_s3_bucket.s3_static_website.id

  block_public_policy     = true
  block_public_acls       = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "site_bucket_website_config" {
  bucket = aws_s3_bucket.s3_static_website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_versioning" "s3_static_versioning" {
  bucket = aws_s3_bucket.s3_static_website.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_cloudfront_origin_access_control" "cf_s3_oac" {
  name                              = "CloudFront S3 OAC"
  description                       = "Securely access an S3 bucket from CloudFront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cf_dist" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.s3_static_website.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.s3_static_website.id
    origin_access_control_id = aws_cloudfront_origin_access_control.cf_s3_oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.s3_static_website.id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy =  "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none" # No geo restrictions
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.s3_static_website.arn}/*"] 
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"] 
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cf_dist.arn] 
    }
  }
}

resource "aws_s3_bucket_policy" "static_site_bucket_policy" {
  bucket = aws_s3_bucket.s3_static_website.id 
  policy = data.aws_iam_policy_document.s3_bucket_policy.json 
}

resource "aws_acm_certificate" "s3_static_website_certificate" {
  domain_name       = "pabeks.com"
  validation_method = "DNS"

  subject_alternative_names = ["www.pabeks.com"]

  tags = {
    Name = "pabeks-certificate"
  }
}
data "aws_route53_zone" "s3_static_website_zone" {
  name = "pabeks.com."
}

resource "aws_route53_record" "s3_static_website_certificate_validation" {
  name    = tolist(aws_acm_certificate.s3_static_website_certificate.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.s3_static_website_certificate.domain_validation_options)[0].resource_record_type
  zone_id = data.aws_route53_zone.s3_static_website_zone.id
  ttl     = 60
  records = [tolist(aws_acm_certificate.s3_static_website_certificate.domain_validation_options)[0].resource_record_value]
}

resource "aws_route53_record" "s3_static_website_certificate_validation" {
  count = length(aws_acm_certificate.s3_static_website_certificate.domain_validation_options)

  name    = aws_acm_certificate.s3_static_website_certificate.domain_validation_options[count.index].resource_record_name
  type    = aws_acm_certificate.s3_static_website_certificate.domain_validation_options[count.index].resource_record_type
  zone_id = data.aws_route53_zone.s3_static_website_zone.id
  ttl     = 60
  records = [aws_acm_certificate.s3_static_website_certificate.domain_validation_options[count.index].resource_record_value]
}
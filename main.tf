provider "aws" {
  region = var.region
}

############################################
#   S3

resource "aws_s3_bucket" "frontend_s3_bucket" {
    bucket = "${var.mdg_s3_frontend}"
    tags = {
        Name    = "FrontEndBucket"
    }
}

resource "aws_s3_bucket" "upload_s3_bucket" {
    bucket = "${var.mdg_s3_upload}"
    tags = {
        Name    = "VideoUploadBucket"
    }
}


resource "aws_s3_bucket" "processed_s3_bucket" {
    bucket = "${var.mdg_s3_processed}"
    tags = {
        Name    = "ProcessedVideoBucket"
    }
}

#################################################
#   Cloudfront


data "aws_iam_policy_document" "origin_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.frontend_s3_bucket}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "fe_s3_policy_cf" {
  bucket = aws_s3_bucket.frontend_s3_bucket
  policy = data.aws_iam_policy_document.origin_bucket_policy.json
}

locals {
  s3_origin_id  = "mdg_s3_origin"
  domain        = "mdgOpenMat.com"
}

data "aws_acm_certificate" "mdg_domain" {
  region    = var.region
  domain    = "*.${local.domain}"
  statuses  = [ "ISSUED" ]
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                                = "default_oac"
  origin_access_control_origin_type   = "s3"
  signing_behavior                    = "always"
  signing_protocol                    = "sigv4"
}

resource "aws_cloudfront_distribution" "mdg_s3_dist" {
  origin {
    domain_name                 = aws_s3_bucket.frontend_s3_bucket.bucket_regional_domain_name
    origin_access_control_id    = aws_cloudfront_origin_access_control.default.id
    origin_id                   = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "${var.frontend_root_object}"

  aliases             = "www.${local.domain}"

   default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

   restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  tags = {
    Environment = "phase1"
  }

  viewer_certificate {
    acm_certificate_arn = data.aws_acm_certificate.domain.arn
    ssl_support_method  = "sni-only"
  }
}

# Route 53 records for cloudfront distribution aliases
data "aws_route53_zone" "mdg_domain" {
  name = local.domain
}

resource "aws_route53_record" "mdg_cloudfront" {
  for_each  = aws_cloudfront_distribution.mdg_s3_dist.aliases
  zone_id   = data.aws_route53_zone.mdg_domain.zone_id
  name      = each.value
  type      = "A"

  alias {
    name                    = aws_cloudfront_distribution.mdg_s3_dist.domain_name
    zone_id                 = aws_cloudfront_distribution.mdg_s3_dist.hosted_zone_id
    evaluate_target_health  = false
  }
}
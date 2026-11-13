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

resource "aws_s3_bucket_public_access_block" "upload_s3_bucket" {
  bucket = aws_s3_bucket.upload_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "upload_s3_bucket" {
  bucket = aws_s3_bucket.upload_s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}


resource "aws_s3_bucket_versioning" "upload_s3_bucket" {
  bucket = aws_s3_bucket.upload_s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "processed_s3_bucket" {
    bucket = "${var.mdg_s3_processed}"
    tags = {
        Name    = "ProcessedVideoBucket"
    }
}

#################################################
#   API Gateway

resource "aws_api_gateway_rest_api" "api" {
  name = "${var.prefix}-api"
  description = "API Gateway for MDG"
}

resource "aws_api_gateway_resource" "resource" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id = aws_api_gateway_rest_api.api.root_resource_id
    path_part = "invoke"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.resource.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.generate_presigned_url.arn}/invocations"
}


#################################################
#   Lambda

resource "aws_iam_role" "lambda_run_role" {
  name = "${var.lambda_run_role}-lambda-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "signed_upload_lambda_policy" {
  name   = "${var.prefix}-signed-upload-lambda-policy"
  role   = aws_iam_role.lambda_run_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.upload_s3_bucket.arn,
          "${aws_s3_bucket.upload_s3_bucket.arn}/*"
        ]
      }
    ]
  })
}


resource "aws_lambda_function" "gen_signed_upload_lambda" {
  function_name = "${var.prefix}-generate-presigned-url-upload"
  role          = "${aws_iam_role.lambda_run_role.arn}"
  runtime = "python3.14"
  memory_size   = 1024
  timeout       = 30
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.upload_s3_bucket.bucket
    }
  }
}


resource "aws_lambda_function" "init_vid_processing_lambda" {
  function_name = var.init_vid_processing_lambda
  role          = "${aws_iam_role.lambda_run_role.arn}"
  runtime = "python3.14"

  environment {
    variables = {
     
    }
  }
}


resource "aws_lambda_function" "gen_signed_stream_lambda" {
  function_name = var.gen_video_stream_signed_lambda
  role          = "${aws_iam_role.lambda_run_role.arn}"
  runtime = "python3.14"

  environment {
    variables = {
     
    }
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
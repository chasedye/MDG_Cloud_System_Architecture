provider "aws" {
  alias = "region"
  region = "${var.region}"
}

############################################
#   S3

resource "aws_s3_bucket" "frontend-s3-bucket" {
    bucket = "${var.mdg-s3-frontend}"
    tags = {
        Name    = "FrontEndBucket"
    }
}

resource "aws_s3_bucket" "upload-s3-bucket" {
    bucket = "${var.mdg-s3-upload}"
    tags = {
        Name    = "VideoUploadBucket"
    }
}

resource "aws_s3_bucket_public_access_block" "upload-s3-bucket" {
  bucket = aws_s3_bucket.upload-s3-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "upload-s3-bucket" {
  bucket = aws_s3_bucket.upload-s3-bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}


resource "aws_s3_bucket_versioning" "upload-s3-bucket" {
  bucket = aws_s3_bucket.upload-s3-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_notification" "upload_notification" {
  bucket = aws_s3_bucket.upload-s3-bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.init-vid-processing-lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [ aws_lambda_permission.allow-init-lambda-from-upload-bucket ]
}

resource "aws_s3_bucket_notification" "upload_notification" {
  bucket = aws_s3_bucket.upload-s3-bucket.id




resource "aws_s3_bucket" "processed-s3-bucket" {
    bucket = "${var.mdg-s3-processed}"
    tags = {
        Name    = "ProcessedVideoBucket"
    }
}

resource "aws_s3_bucket_cors_configuration" "cors-config" {
  bucket = aws_s3_bucket.processed-s3-bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

#################################################
#   API Gateway

resource "aws_api_gateway_rest_api" "api" {
  name = "${var.prefix}-api"
  description = "API Gateway for MDG"
}

# Signed upload video url  
resource "aws_api_gateway_resource" "upload-resource" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id = aws_api_gateway_rest_api.api.root_resource_id
    path_part = "upload"
}

resource "aws_api_gateway_method" "upload-method" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.upload-resource.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload-integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.upload-resource.id
  http_method             = aws_api_gateway_method.upload-method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.gen-signed-upload-lambda.arn}/invocations"
}

resource "aws_lambda_permission" "allow-gateway-upload-lambda" {
  statement_id  = "${lower(var.prefix)}-allow-api-gateway-invoke-upload-lambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gen-signed-upload-lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "upload-deployment" {
  depends_on  = [aws_api_gateway_integration.upload-integration]
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_stage" "upload-stage" {
  deployment_id = aws_api_gateway_deployment.upload-deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "${var.prefix}-upload-stage"
}


# Signed stream video url
resource "aws_api_gateway_resource" "stream-resource" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id = aws_api_gateway_rest_api.api.root_resource_id
    path_part = "stream"
}

resource "aws_api_gateway_method" "stream-method" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.stream-resource.id
  http_method = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "stream-integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.stream-resource.id
  http_method             = aws_api_gateway_method.stream-method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.gen-signed-stream-lambda.arn}/invocations"
}

resource "aws_lambda_permission" "allow-gateway-stream-lambda" {
  statement_id  = "${lower(var.prefix)}-allow-api-gateway-invoke-stream-lambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gen-signed-stream-lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "stream-deployment" {
  depends_on  = [aws_api_gateway_integration.stream-integration]
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_stage" "stream-stage" {
  deployment_id = aws_api_gateway_deployment.stream-deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "${var.prefix}-stream-stage"
}

output "api_url" {
  description = "The URL of the API Gateway REST API"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.region}.amazonaws.com/dev/invoke"
}

#################################################
#   IAM Policies Setup

# Upload Lambda
resource "aws_iam_role" "signed-upload-lambda-role" {
  name = "${var.prefix}-signed-upload-lambda-role"
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
  role   = aws_iam_role.signed-upload-lambda-role.id
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
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.upload-s3-bucket.arn,
          "${aws_s3_bucket.upload-s3-bucket.arn}/*"
        ]
      }
    ]
  })
}

# Stream Video Lambda
resource "aws_iam_role" "signed-stream-lambda-role" {
  name = "${var.prefix}-signed-stream-lambda-role"
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


resource "aws_iam_role_policy" "signed-stream-lambda-policy" {
  name   = "${var.prefix}-signed-stream-lambda-policy"
  role   = aws_iam_role.signed-stream-lambda-role.id
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
          #"s3:PutObject", probably dont need
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.processed-s3-bucket.arn,
          "${aws_s3_bucket.processed-s3-bucket.arn}/*"
        ]
      }
    ]
  })
}



############################################################
#     Lambda

resource "aws_lambda_function" "gen-signed-upload-lambda" {
  function_name = "${var.prefix}-generate-signed-upload"
  filename = "Lambda/sample.zip"
  role          = aws_iam_role.signed-upload-lambda-role.arn
  runtime = "python3.13"
  handler = "sample.lambda_handler"
  memory_size   = 1024
  timeout       = 30
  environment {
    variables = {
      DestinationBucket = aws_s3_bucket.upload-s3-bucket.bucket
    }
  }
}


resource "aws_lambda_function" "gen-signed-stream-lambda" {
  function_name = "${var.prefix}-gen-signed-stream-lambda"
  filename = "Lambda/sample.zip"
  role          = "${aws_iam_role.signed-stream-lambda-role.arn}"
  runtime = "python3.13"
  handler = "sample.lambda_handler"
  environment {
     variables = {
      BUCKET_NAME = aws_s3_bucket.processed-s3-bucket.bucket
    }
  }
}



#################################################
#   Cloudfront


data "aws_iam_policy_document" "origin-bucket-policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.frontend-s3-bucket.arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.mdg-s3-dist.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "fe-s3-policy-cf" {
  bucket = aws_s3_bucket.frontend-s3-bucket.id
  policy = data.aws_iam_policy_document.origin-bucket-policy.json
}

locals {
  s3-origin-id  = "mdg_s3_origin"
}

resource "aws_acm_certificate" "cert" {
  domain_name    = "${var.mdg-domain-name}.com"
  subject_alternative_names = ["${var.mdg-domain-name}.com"]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Route 53 records for cloudfront distribution aliases
resource "aws_route53_zone" "zone" {
  name = "${var.mdg-domain-name}.com"
}

resource "aws_route53_record" "mdg-record" {

  name            = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_value]
  type            = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_type
  zone_id         = aws_route53_zone.zone.zone_id
  ttl             = 300
  allow_overwrite = true
}

output "zone_name_servers" {
  value = aws_route53_zone.zone.name_servers
}

resource "aws_acm_certificate_validation" "cert-validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.mdg-record.fqdn]
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                                = "default-oac"
  origin_access_control_origin_type   = "s3"
  signing_behavior                    = "always"
  signing_protocol                    = "sigv4"
}

resource "aws_cloudfront_distribution" "mdg-s3-dist" {
  origin {
    domain_name                 = aws_s3_bucket.frontend-s3-bucket.bucket_regional_domain_name
    origin_access_control_id    = aws_cloudfront_origin_access_control.default.id
    origin_id                   = local.s3-origin-id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "${var.frontend-root-object}"

  aliases             = ["${var.mdg-domain-name}.com"]

   default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3-origin-id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
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
    acm_certificate_arn = aws_acm_certificate_validation.cert-validation.certificate_arn
    ssl_support_method  = "sni-only"
    minimum_protocol_version = "${var.minTLS}"
  }
}

resource "aws_route53_record" "cloudfront_alias" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = "www.${var.mdg-domain-name}.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.mdg-s3-dist.domain_name
    zone_id                = aws_cloudfront_distribution.mdg-s3-dist.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cloudfront_alias_ipv6" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = "www.${var.mdg-domain-name}.com"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.mdg-s3-dist.domain_name
    zone_id                = aws_cloudfront_distribution.mdg-s3-dist.hosted_zone_id
    evaluate_target_health = false
  }
}

########################################################
#   Elemental Media Convert

resource "aws_media_convert_queue" "queue" {
    name   =  "${var.prefix}-media-convert-queue"
    pricing_plan = var.pricing-plan
    description = var.media-convert-description
}

resource "aws_iam_role" "media-convert-role" {
  name = "${var.prefix}-media-convert-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "mediaconvert.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_role_policy" "media-convert-role-policy" {
  name   = "${var.prefix}-media-convert-policy"
  role   = aws_iam_role.media-convert-role.id
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
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.upload-s3-bucket.arn,
          "${aws_s3_bucket.upload-s3-bucket.arn}/*"
        ]
      },
       {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.processed-s3-bucket.arn,
          "${aws_s3_bucket.processed-s3-bucket.arn}/*"
        ]
      }
    ]
  })
}

# Lambda for automatic processing

resource "aws_iam_role" "init-media-convert-lambda-role" {
  name = "${var.prefix}-init-media-convert-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }]
  })
}

resource "aws_iam_role_policy" "init-media-convert-lambda-policy" {
  name   = "${var.prefix}-init-media-convert-lambda-policy"
  role   = aws_iam_role.init-media-convert-lambda-role.id
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
        Sid = "PassRole",
        Action = [
          "iam:PassRole"
        ],
        Resource = [
          aws_iam_role.media-convert-role.arn
        ],
        "Condition": {
          "StringEquals": { "iam:PassedToService": "mediaconvert.amazonaws.com" }
        }
      },
      {
        Effect = "Allow",
        Sid = "MediaConvertService",
        Action = [
          "mediaconvert:CreateJob",
          "mediaconvert:GetJob",
          "mediaconvert:DescribeEndpoints"
        ],
        Resource = [
          "*"
        ]
      },
      {
        Sid = "ReadUploads",
        Effect = "Allow",
        Action = "s3:GetObject",
        Resource = "arn:aws:s3:::mdg-s3-video-upload-bucket/*"
      },
      {
        Sid = "ListUploads",
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = [
          "${aws_s3_bucket.upload-s3-bucket.arn}",
        ]
      }
    ]
  })
}



resource "aws_lambda_function" "init-vid-processing-lambda" {
  function_name = "${var.prefix}-init-vid-process-lambda"
  filename = "${var.local-init-lambda-zip-path}"
  role          = aws_iam_role.init-media-convert-lambda-role.arn
  runtime = "python3.13"
  handler = "init-vid-process.lambda_handler"
  environment {
    variables = {
        DestinationBucket = "${aws_s3_bucket.processed-s3-bucket.bucket}"
        MediaConvertRole = "${aws_iam_role.media-convert-role.arn}"
        MediaConvertQueue = "${aws_media_convert_queue.queue.arn}"
        LAMBDA_REGION  = "${var.region}"    
        Application = "VOD"
    }
  }
}

resource "aws_lambda_permission" "allow-init-lambda-from-upload-bucket" {
  statement_id  = "AllowExecutionFromS3Bucket1"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.init-vid-processing-lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.upload-s3-bucket.arn
}
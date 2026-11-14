provider "aws" {
  region = var.region
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

resource "aws_s3_bucket" "processed-s3-bucket" {
    bucket = "${var.mdg-s3-processed}"
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

# Signed upload video url  
resource "aws_api_gateway_resource" "upload-resource" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id = aws_api_gateway_rest_api.api.root_resource_id
    path_part = "invoke"
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


# Signed stream video url
resource "aws_api_gateway_resource" "stream-resource" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id = aws_api_gateway_rest_api.api.root_resource_id
    path_part = "invoke"
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

# 


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
          #"s3:GetObject",     may need but probably dont
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

data "archive_file" "example-py-zip" {
  type        = "zip"
  source_dir  = "${path.module}/../Lambda/sample.py"
  output_path = "${path.module}/../Lambda/sample.zip"
}

resource "aws_lambda_function" "gen-signed-upload-lambda" {
  function_name = "${var.prefix}-generate-signed-upload"
  filename = "../Lambda/sample.zip"
  role          = aws_iam_role.signed-upload-lambda-role.arn
  runtime = "python3.14"
  memory_size   = 1024
  timeout       = 30
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.upload-s3-bucket.bucket
    }
  }
}

# Pass unprocessed videos to media convert Lambda
resource "aws_lambda_function" "init-vid-processing-lambda" {
  function_name = var.init-vid-processing-lambda
  filename = "../Lambda/sample.zip"
  role          = aws_iam_role
  runtime = "python3.14"

  environment {
    variables = {
     
    }
  }
}


resource "aws_lambda_function" "gen-signed-stream-lambda" {
  function_name = "${var.prefix}-gen-signed-stream-lambda"
  filename = "../Lambda/sample.zip"
  role          = "${aws_iam_role.lambda_run_role.arn}"
  runtime = "python3.14"

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
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.frontend-s3-bucket}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.mdg-s3-dist.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "fe-s3-policy-cf" {
  bucket = aws_s3_bucket.frontend-s3-bucket
  policy = data.aws_iam_policy_document.origin-bucket-policy.json
}

locals {
  s3-origin-id  = "mdg_s3_origin"
  domain        = "mdgOpenMat.com"
}

data "aws_acm_certificate" "mdg-domain" {
  domain    = "*.${local.domain}"
  statuses  = [ "ISSUED" ]
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

  aliases             = "www.${local.domain}"

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
data "aws_route53_zone" "mdg-domain" {
  name = local.domain
}

resource "aws_route53_record" "mdg-cloudfront" {
  for_each  = aws_cloudfront_distribution.mdg-s3-dist.aliases
  zone_id   = data.aws_route53_zone.mdg-domain.zone_id
  name      = each.value
  type      = "A"

  alias {
    name                    = aws_cloudfront_distribution.mdg-s3-dist.domain_name
    zone_id                 = aws_cloudfront_distribution.mdg-s3-dist.hosted_zone_id
    evaluate_target_health  = false
  }
}


########################################################
#   Elemental Media Convert


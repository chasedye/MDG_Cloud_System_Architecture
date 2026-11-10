provider "aws" {
  region = var.region
}

############################################
#   S3

resource "aws_s3_bucket" "front_end_code_bucket" {
    bucket = "${var.mdg_s3_frontend}"

    tags = {
        Name    = "FrontEndBucket"
    }
}

resource "aws_fe_s3_bucket_acl" "fe_s3_private" {
    bucket = aws_s3_bucket.front_end_code_bucket.id
    acl = "private"
}


resource "aws_s3_bucket" "upload_video_bucket" {
    bucket = "${var.mdg_s3_upload}"

    tags = {
        Name    = "VideoUploadBucket"
    }
}

resource "aws_fe_s3_bucket_acl" "vub_s3_private" {
    bucket = aws_s3_bucket.upload_video_bucket.id
    acl = "private"
}


resource "aws_s3_bucket" "processed_video_bucket" {
    bucket = "MDG_processed_video_bucket"

    tags = {
        Name    = "ProcessedVideoBucket"
    }
}

resource "aws_fe_s3_bucket_acl" "pvb_s3_private" {
    bucket = aws_s3_bucket.processed_video_bucket.id
    acl = "private"
}


#################################################
#   Cloudfront
resource "aws_iam_policy" "${mdg_cloudfront_policy}" {
  name        = "${mdg_cloudfront_policy}-policy"
  description = "Allow cloudfront access to se front end bucket"

  policy = <<EOT
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListAllMyBuckets"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.bucket.arn}"
    }
  ]

}
EOT
}


    origin_access_control = {
        s3_oac = {
        description      = "CloudFront access to S3"
        origin_type      = "s3"
        signing_behavior = "always"
        signing_protocol = "sigv4"
        }
    }

    origin = {
        s3_bucket = {
        domain_name = "my-bucket.s3.amazonaws.com"
        }
    }

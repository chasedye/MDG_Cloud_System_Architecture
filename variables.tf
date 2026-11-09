
# Write iam wrole for lambda

variable "front_end_bucket" {
    description = "S3 bucket to hold compiled code for cloudfront distribution"
    type = "string"
}

variable "upload_video_bucket" {
    description = "S3 bucket for uploaded and unprocessed videos"
    type = "string"
}

variable "processed_video_bucket" { 
    description = "S3 bucket for processed videos"
    type = "string"
}

variable "mdg_cloudfront" {
    description = "Cloudfront"
}
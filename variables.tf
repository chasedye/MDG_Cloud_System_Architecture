
variable "region" {
    description = "AWS MDG Region"
    type        = "string"
    default     = "us-east-1"
}

#   Website

variable "mdg_cloudfront_policy" {
    type        = "string"
    default     = "mdg_cloudfront_s3_access_iam"
}

variable "mdg_s3_frontend" {
    type        = "string"
    default     = "mdg_front_end_s3_bucket"
}

variable "mdg_cloudfront_dist" {
    type        = "string"
    default     = "mdg_cloudfront_distribution"
}

#   Video Upload Process

variable "mdg_s3_upload" {
    type        = "string"
    default     = "mdg_s3_video_upload_bucket"
}

variable "mdg_s3_processed" { 
    type        = "string"
    default     = "mdg_s3_proccesed_video_bucket"
}

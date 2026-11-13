
variable "region" {
    description = "AWS MDG Region"
    type        = string
    default     = "us-east-1"
}

#   Website

variable "mdg_cloudfront_policy" {
    type        = string
    default     = "mdg_cloudfront_s3_access_iam"
}

variable "mdg_s3_frontend" {
    type        = string
    default     = "mdg_front_end_s3_bucket"
}

variable "frontend_root_object" {
    type        = string
    default     = "index.html"
}
variable "mdg_cloudfront_dist" {
    type        = string
    default     = "mdg_cloudfront_distribution"
}

#   Video Upload Process

variable "prefix" {
    description = "Prefix of variables for MDG"
    type = string
    default = "mdg"
}
variable "init_vid_processing_lambda" {
    type = string
    default = "mdg_init_video_processing_lambda"
}

variable "gen_video_upload_signed_lambda" {
    type = string   
    default = "mdg_gen_video_upload_signed_lambda"
}

variable "gen_video_stream_signed_lambda" {
    type = string
    default = "mdg_gen_video_stream_signed_lambda"
}

variable "lambda_run_role" {
    type = string
    default = "lambda_run_role"
}
variable "mdg_s3_upload" {
    type        = string
    default     = "mdg_s3_video_upload_bucket"
}

variable "mdg_s3_processed" { 
    type        = string
    default     = "mdg_s3_proccesed_video_bucket"
}


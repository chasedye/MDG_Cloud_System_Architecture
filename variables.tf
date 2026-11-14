
variable "region" {
    description = "AWS MDG Region"
    type        = string
    default     = "us-east-1"
}

#   Website

variable "mdg-cloudfront-policy" {
    type        = string
    default     = "mdg-cloudfront-s3-access-iam"
}

variable "mdg-s3-frontend" {
    type        = string
    default     = "mdg-front-end-s3-bucket"
}

variable "frontend-root-object" {
    type        = string
    default     = "index.html"
}
variable "mdg-cloudfront-dist" {
    type        = string
    default     = "mdg-cloudfront-distribution"
}

#   Video Upload Process

variable "prefix" {
    description = "Prefix of variables for MDG"
    type = string
    default = "mdg"
}
variable "init-vid-processing-lambda" {
    type = string
    default = "mdg-init-video-processing-lambda"
}

variable "gen-video-upload-signed-lambda" {
    type = string   
    default = "mdg-gen-video-upload-signed-lambda"
}

variable "gen-video-stream-signed-lambda" {
    type = string
    default = "mdg-gen-video-stream-signed-lambda"
}

variable "lambda-run-role" {
    type = string
    default = "lambda-run-role"
}
variable "mdg-s3-upload" {
    type        = string
    default     = "mdg-s3-video-upload-bucket"
}

variable "mdg-s3-processed" { 
    type        = string
    default     = "mdg-s3-proccesed-video-bucket"
}


provider "aws" {
  region = "us-east-2"
}


resource "aws_s3_bucket" "front_end_code_bucket" {
    bucket = "MDG_front_end_code"
}
# S3 buckets for the application's object-storage boundaries.
#
# This module is environment-agnostic on purpose: it names no endpoint and no
# credential. Development points the AWS provider at fakecloud and production
# points it at AWS, and nothing else differs. See ../../environments/development.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}

# The application serves objects through Shrine, never through a bucket-level
# public grant. Blocking public access here means a later `acl = "public-read"`
# fails loudly instead of silently publishing user uploads.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

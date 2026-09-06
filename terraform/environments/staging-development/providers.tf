# Staging-development environment: FakeCloud is the S3-compatible endpoint for
# this integration VM. Production must not use this provider configuration.
#
# Bucket names here are distinct from terraform/environments/development so
# staging-development never shares objects with a local development stack.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "local" {}
}

provider "aws" {
  region = var.region

  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  s3_use_path_style = true

  endpoints {
    s3  = var.fakecloud_endpoint
    sts = var.fakecloud_endpoint
    iam = var.fakecloud_endpoint
  }
}

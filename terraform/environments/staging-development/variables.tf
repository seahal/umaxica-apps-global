variable "fakecloud_endpoint" {
  description = "Base URL of the staging-development FakeCloud emulator."
  type        = string
  default     = "http://localhost:4566"
}

variable "region" {
  description = "Region string. Must match OBJECT_STORAGE_REGION for this environment."
  type        = string
  default     = "us-east-1"
}

variable "avatar_bucket" {
  description = "Avatar staging-development bucket. Must not match the local development bucket."
  type        = string
  default     = "umaxica-avatar-staging"
}

variable "publishing_bucket" {
  description = "Publishing staging-development bucket. Must not match the local development bucket."
  type        = string
  default     = "umaxica-publishing-staging"
}

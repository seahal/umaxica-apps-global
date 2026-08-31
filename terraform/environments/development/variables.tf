# STATUS: adoption is still being evaluated. Nothing under `terraform/` has been
# applied against fakecloud from either the host or the `core` container, so
# treat the resources here as unverified HCL rather than a working environment.

variable "fakecloud_endpoint" {
  description = <<-DESC
    Base URL of the local fakecloud emulator. The default is the loopback
    publication in compose.yaml, which is correct when Terraform runs on the
    developer's host. From inside the `core` container, override it:
    TF_VAR_fakecloud_endpoint=http://fakecloud:4566
  DESC
  type        = string
  default     = "http://localhost:4566"
}

variable "region" {
  description = "Region string. Must match OBJECT_STORAGE_REGION in compose.yaml."
  type        = string
  default     = "us-east-1"
}

variable "object_storage_bucket" {
  description = "Development bucket name. Must match OBJECT_STORAGE_BUCKET in compose.yaml."
  type        = string
  default     = "umaxica-local"
}

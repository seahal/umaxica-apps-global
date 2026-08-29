variable "fakecloud_endpoint" {
  description = "Base URL of the local fakecloud emulator, as published on loopback by compose.yaml."
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

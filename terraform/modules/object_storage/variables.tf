variable "bucket_name" {
  description = "Name of the S3 bucket. Must match the OBJECT_STORAGE_BUCKET_* value the application reads."
  type        = string
}

variable "versioning_enabled" {
  description = "Whether to retain non-current object versions."
  type        = bool
  default     = true
}

output "avatar_bucket" {
  description = "Staging-development Avatar S3 bucket name."
  value       = module.avatar_object_storage.bucket
}

output "publishing_bucket" {
  description = "Staging-development publishing S3 bucket name."
  value       = module.publishing_object_storage.bucket
}

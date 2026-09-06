output "avatar_bucket" {
  description = "Development Avatar S3 bucket name."
  value       = module.avatar_object_storage.bucket
}

output "publishing_bucket" {
  description = "Development publishing S3 bucket name."
  value       = module.publishing_object_storage.bucket
}

output "msk_cluster_arn" {
  description = "Development MSK cluster ARN."
  value       = module.streaming.arn
}

output "msk_bootstrap_brokers" {
  description = <<-DESC
    Bootstrap brokers reported by the fakecloud MSK control plane. Nothing is
    listening on these addresses in this repository's Compose stack: fakecloud is
    given no container runtime socket, so it spawns no Kafka broker.
  DESC
  value       = module.streaming.bootstrap_brokers
}

output "bucket" {
  description = "Development S3 bucket name."
  value       = module.object_storage.bucket
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

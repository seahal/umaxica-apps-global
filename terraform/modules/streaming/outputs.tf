output "arn" {
  description = "Cluster ARN."
  value       = aws_msk_cluster.this.arn
}

output "bootstrap_brokers" {
  description = "Plaintext bootstrap broker list. Empty unless the cluster allows PLAINTEXT."
  value       = aws_msk_cluster.this.bootstrap_brokers
}

output "bootstrap_brokers_tls" {
  description = "TLS bootstrap broker list."
  value       = aws_msk_cluster.this.bootstrap_brokers_tls
}

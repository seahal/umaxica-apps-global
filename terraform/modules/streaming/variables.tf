variable "cluster_name" {
  description = "MSK cluster name."
  type        = string
}

variable "kafka_version" {
  description = "Apache Kafka version the cluster runs."
  type        = string
}

variable "client_subnets" {
  description = "Subnet IDs the brokers attach to. One broker is created per subnet."
  type        = list(string)
}

variable "security_groups" {
  description = "Security group IDs applied to the broker ENIs."
  type        = list(string)
}

variable "broker_instance_type" {
  description = "Broker instance type."
  type        = string
}

variable "broker_volume_size" {
  description = "Per-broker EBS volume size in GiB."
  type        = number
}

variable "client_broker_encryption" {
  description = "In-transit encryption between clients and brokers: TLS, TLS_PLAINTEXT, or PLAINTEXT."
  type        = string
}

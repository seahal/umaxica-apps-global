# Amazon MSK cluster for the application's event stream.
#
# Environment-agnostic like ../object_storage: the network it lands in is passed
# in, so development (fakecloud) and production (real AWS) share this definition
# and differ only in the provider configuration and the subnets they hand over.
#
# NOTE for development: fakecloud serves the MSK control plane, but this
# repository's Compose stack deliberately gives it no container runtime socket,
# so no real broker is spawned and `bootstrap_brokers` addresses nothing
# listening. Producing and consuming is therefore not exercised locally. See
# docs/operations/local-aws-fakecloud.md.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

resource "aws_msk_cluster" "this" {
  cluster_name           = var.cluster_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = length(var.client_subnets)

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.client_subnets
    security_groups = var.security_groups

    storage_info {
      ebs_storage_info {
        volume_size = var.broker_volume_size
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = var.client_broker_encryption
      in_cluster    = true
    }
  }
}

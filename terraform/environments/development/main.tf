# Per-boundary development buckets the Rails `core` service reads through
# OBJECT_STORAGE_BUCKET_AVATAR and OBJECT_STORAGE_BUCKET_PUBLISHING. Keeping
# them here rather than in a Compose init script is the point of this directory:
# bucket lifecycle is Terraform's responsibility in every environment.
module "avatar_object_storage" {
  source = "../../modules/object_storage"

  bucket_name = var.avatar_bucket
}

module "publishing_object_storage" {
  source = "../../modules/object_storage"

  bucket_name = var.publishing_bucket
}

# Minimal network for the MSK cluster. Real Amazon MSK requires client subnets in
# distinct availability zones, so the development environment models that rather
# than passing placeholder IDs, which keeps the module signature honest for
# production reuse.
resource "aws_vpc" "streaming" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "umaxica-development-streaming"
  }
}

resource "aws_subnet" "streaming" {
  count = 3

  vpc_id            = aws_vpc.streaming.id
  cidr_block        = cidrsubnet(aws_vpc.streaming.cidr_block, 8, count.index)
  availability_zone = "${var.region}${element(["a", "b", "c"], count.index)}"

  tags = {
    Name = "umaxica-development-streaming-${count.index}"
  }
}

resource "aws_security_group" "streaming" {
  name   = "umaxica-development-streaming"
  vpc_id = aws_vpc.streaming.id
}

module "streaming" {
  source = "../../modules/streaming"

  cluster_name    = "umaxica-development"
  kafka_version   = "3.8.0"
  client_subnets  = aws_subnet.streaming[*].id
  security_groups = [aws_security_group.streaming.id]

  broker_instance_type = "kafka.t3.small"
  broker_volume_size   = 10

  # PLAINTEXT so that a bootstrap broker address is returned at all. Production
  # must use TLS; that difference is deliberate and recorded in
  # docs/operations/local-aws-fakecloud.md.
  client_broker_encryption = "PLAINTEXT"
}

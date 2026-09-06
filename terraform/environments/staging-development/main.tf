module "avatar_object_storage" {
  source = "../../modules/object_storage"

  bucket_name = var.avatar_bucket
}

module "publishing_object_storage" {
  source = "../../modules/object_storage"

  bucket_name = var.publishing_bucket
}

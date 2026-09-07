# frozen_string_literal: true

require "test_helper"

class ObjectStorageBucketIsolationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "development compose buckets are distinct per boundary" do
    contract = Rails.root.join(".env.devcontainer.example").read

    assert_match(/OBJECT_STORAGE_BUCKET_AVATAR=umaxica-avatar-development/, contract)
    assert_match(/OBJECT_STORAGE_BUCKET_PUBLISHING=umaxica-publishing-development/, contract)
    assert_match(%r{OBJECT_STORAGE_ENDPOINT=http://fakecloud:4566}, contract)
    assert_no_match(/OBJECT_STORAGE_BUCKET=umaxica-local/, contract)
  end

  test "staging-development terraform buckets never share development names" do
    staging = Rails.root.join("terraform/environments/staging-development/variables.tf").read
    development = Rails.root.join("terraform/environments/development/variables.tf").read

    assert_match(/umaxica-avatar-staging/, staging)
    assert_match(/umaxica-publishing-staging/, staging)
    assert_match(/umaxica-avatar-development/, development)
    assert_match(/umaxica-publishing-development/, development)
    assert_no_match(/umaxica-avatar-development/, staging)
    assert_no_match(/umaxica-publishing-development/, staging)
  end

  test "avatar and publishing storages resolve to different buckets" do
    saved_avatar = ENV["OBJECT_STORAGE_BUCKET_AVATAR"]
    saved_publishing = ENV["OBJECT_STORAGE_BUCKET_PUBLISHING"]
    ENV["OBJECT_STORAGE_BUCKET_AVATAR"] = "umaxica-avatar-development"
    ENV["OBJECT_STORAGE_BUCKET_PUBLISHING"] = "umaxica-publishing-development"

    assert_equal "umaxica-avatar-development", ObjectStorage::Boundary.bucket(:avatar)
    assert_equal "umaxica-publishing-development", ObjectStorage::Boundary.bucket(:publishing)
    assert_not_equal ObjectStorage::Boundary.bucket(:avatar), ObjectStorage::Boundary.bucket(:publishing)
  ensure
    saved_avatar.nil? ? ENV.delete("OBJECT_STORAGE_BUCKET_AVATAR") : ENV["OBJECT_STORAGE_BUCKET_AVATAR"] = saved_avatar
    saved_publishing.nil? ? ENV.delete("OBJECT_STORAGE_BUCKET_PUBLISHING") : ENV["OBJECT_STORAGE_BUCKET_PUBLISHING"] =
                                                                               saved_publishing
  end

  test "production S3 storage refuses a FakeCloud endpoint" do
    saved_endpoint = ENV["OBJECT_STORAGE_ENDPOINT"]
    saved_region = ENV["OBJECT_STORAGE_REGION"]
    ENV["OBJECT_STORAGE_ENDPOINT"] = "http://fakecloud:4566"
    ENV["OBJECT_STORAGE_REGION"] = "us-east-1"

    error =
      assert_raises(ArgumentError) do
        ObjectStorage::ShrineConfiguration.s3_storage(bucket: "umaxica-avatar", prefix: "store")
      end

    assert_match("OBJECT_STORAGE_ENDPOINT", error.message)
  ensure
    saved_endpoint.nil? ? ENV.delete("OBJECT_STORAGE_ENDPOINT") : ENV["OBJECT_STORAGE_ENDPOINT"] = saved_endpoint
    saved_region.nil? ? ENV.delete("OBJECT_STORAGE_REGION") : ENV["OBJECT_STORAGE_REGION"] = saved_region
  end
end

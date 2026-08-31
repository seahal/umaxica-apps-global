# frozen_string_literal: true

require "securerandom"
require_relative "../object_storage_environment"

module ObjectStorageTasks
  module_function

  REQUIRED_ENVIRONMENT = %w(
    OBJECT_STORAGE_ENDPOINT
    OBJECT_STORAGE_REGION
    OBJECT_STORAGE_BUCKET
    OBJECT_STORAGE_ACCESS_KEY_ID
    OBJECT_STORAGE_SECRET_ACCESS_KEY
    OBJECT_STORAGE_FORCE_PATH_STYLE
  ).freeze

  # Environment reading, including the `<NAME>_FILE` secret-mount convention, is
  # shared with the Shrine storage configuration in ObjectStorage::Environment.
  #
  # This task keeps its own single OBJECT_STORAGE_BUCKET: it provisions and smoke
  # tests the local development bucket and is not part of the attachment path,
  # which resolves a bucket per storage boundary instead.
  def configuration
    values = REQUIRED_ENVIRONMENT.index_with { |name| ObjectStorage::Environment.fetch(name) }

    values.merge(
      "OBJECT_STORAGE_FORCE_PATH_STYLE" =>
        ObjectStorage::Environment.fetch_boolean("OBJECT_STORAGE_FORCE_PATH_STYLE"),
    )
  end

  def client(configuration)
    require "aws-sdk-s3"

    Aws::S3::Client.new(
      endpoint: configuration.fetch("OBJECT_STORAGE_ENDPOINT"),
      region: configuration.fetch("OBJECT_STORAGE_REGION"),
      force_path_style: configuration.fetch("OBJECT_STORAGE_FORCE_PATH_STYLE"),
      credentials: Aws::Credentials.new(
        configuration.fetch("OBJECT_STORAGE_ACCESS_KEY_ID"),
        configuration.fetch("OBJECT_STORAGE_SECRET_ACCESS_KEY"),
      ),
    )
  end

  def ensure_bucket!(client, bucket)
    client.head_bucket(bucket: bucket)
    puts "Object storage bucket exists: #{bucket}"
  rescue Aws::S3::Errors::NotFound
    begin
      client.create_bucket(bucket: bucket)
      puts "Created object storage bucket: #{bucket}"
    rescue Aws::S3::Errors::BucketAlreadyOwnedByYou
      client.head_bucket(bucket: bucket)
      puts "Object storage bucket already exists: #{bucket}"
    end
  end

  def smoke!(client, bucket)
    key = "smoke/#{SecureRandom.uuid}"
    expected_body = "Umaxica object storage smoke test: #{key}"
    uploaded = false

    begin
      client.put_object(bucket: bucket, key: key, body: expected_body)
      uploaded = true

      head = client.head_object(bucket: bucket, key: key)
      unless head.content_length == expected_body.bytesize
        raise RuntimeError, "Object size mismatch: expected #{expected_body.bytesize}, got #{head.content_length}"
      end

      response = client.get_object(bucket: bucket, key: key)
      begin
        actual_body = response.body.read
      ensure
        response.body.close
      end
      raise RuntimeError, "Object body mismatch for #{key}" unless actual_body == expected_body

      puts "Object storage PUT, HEAD, and GET succeeded: #{key}"
    ensure
      if uploaded
        client.delete_object(bucket: bucket, key: key)
        puts "Deleted smoke-test object: #{key}"
      end
    end

    begin
      client.head_object(bucket: bucket, key: key)
      raise RuntimeError, "Smoke-test object still exists after DELETE: #{key}"
    rescue Aws::S3::Errors::NotFound
      puts "Object storage DELETE verified: #{key}"
    end
  end
end

namespace :object_storage do
  desc "Create the configured object-storage bucket if it does not exist"
  task prepare: :environment do
    configuration = ObjectStorageTasks.configuration
    client = ObjectStorageTasks.client(configuration)
    ObjectStorageTasks.ensure_bucket!(client, configuration.fetch("OBJECT_STORAGE_BUCKET"))
  end

  desc "Run a destructive temporary-object smoke test against object storage"
  task smoke: :environment do
    configuration = ObjectStorageTasks.configuration
    client = ObjectStorageTasks.client(configuration)
    bucket = configuration.fetch("OBJECT_STORAGE_BUCKET")

    ObjectStorageTasks.ensure_bucket!(client, bucket)
    ObjectStorageTasks.smoke!(client, bucket)
  end
end

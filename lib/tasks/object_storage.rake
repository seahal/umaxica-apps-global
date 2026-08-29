# frozen_string_literal: true

require "securerandom"

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

  # Credentials are delivered as mounted Podman secrets, so their values are read
  # from a file path rather than from the variable itself. This mirrors
  # POSTGRESQL_PASSWORD_FILE in config/database.yml; the direct variables remain
  # supported for deployments whose credential provider exports values inline.
  FILE_BACKED_ENVIRONMENT = %w(
    OBJECT_STORAGE_ACCESS_KEY_ID
    OBJECT_STORAGE_SECRET_ACCESS_KEY
  ).freeze

  def configuration
    values =
      REQUIRED_ENVIRONMENT.to_h do |name|
        value = fetch_environment(name)
        raise ArgumentError, "#{name} must not be blank" if value.empty?

        [name, value]
      end

    values.merge(
      "OBJECT_STORAGE_FORCE_PATH_STYLE" => parse_boolean(
        "OBJECT_STORAGE_FORCE_PATH_STYLE",
        values.fetch("OBJECT_STORAGE_FORCE_PATH_STYLE"),
      ),
    )
  end

  # A configured `<NAME>_FILE` is authoritative: a missing or unreadable file
  # raises instead of falling back to the direct variable, so a broken secret
  # mount cannot quietly authenticate with stale or absent credentials.
  def fetch_environment(name)
    path = ENV["#{name}_FILE"] if FILE_BACKED_ENVIRONMENT.include?(name)
    return ENV.fetch(name) if path.blank?

    File.read(path).strip
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
    expected_body = "Umaxica RustFS smoke test: #{key}"
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

  def parse_boolean(name, value)
    return true if value == "true"
    return false if value == "false"

    raise ArgumentError, "#{name} must be exactly true or false"
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

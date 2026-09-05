# typed: false
# frozen_string_literal: true

require "test_helper"

# Object storage resolves to a different backend per environment and deployment
# tier. Development and production-shaped staging use an S3-compatible endpoint,
# real production uses AWS S3, and test remains in memory without network I/O.
class ObjectStorageShrineConfigurationModesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  DEVELOPMENT = ActiveSupport::StringInquirer.new("development")
  PRODUCTION = ActiveSupport::StringInquirer.new("production")
  TEST = ActiveSupport::StringInquirer.new("test")

  def with_env(overrides)
    saved = overrides.keys.index_with { |key| ENV[key] }
    overrides.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def without_s3_compatible_configuration(&)
    with_env(ObjectStorage::ShrineConfiguration::S3_COMPATIBLE_VARIABLES.index_with { nil }, &)
  end

  def with_s3_compatible_configuration(&)
    with_env(
      {
        "OBJECT_STORAGE_ENDPOINT" => "https://objects.example",
        "OBJECT_STORAGE_REGION" => "jp-north-1",
        "OBJECT_STORAGE_ACCESS_KEY_ID" => "access-key",
        "OBJECT_STORAGE_SECRET_ACCESS_KEY" => "secret-key",
        "OBJECT_STORAGE_FORCE_PATH_STYLE" => "true",
      },
      &
    )
  end

  test "development selects S3-compatible storage even when configuration is missing" do
    without_s3_compatible_configuration do
      assert_equal :s3_compatible, ObjectStorage::ShrineConfiguration.mode(DEVELOPMENT)
    end
  end

  test "development with an s3-compatible endpoint configured uses that endpoint" do
    with_s3_compatible_configuration do
      assert_equal :s3_compatible, ObjectStorage::ShrineConfiguration.mode(DEVELOPMENT)

      # No boundary is registered, so every bucket lookup is refused by name --
      # a deployment is never asked for a bucket it has not declared.
      error =
        assert_raises(ArgumentError) do
          ObjectStorage::ShrineConfiguration.build_storage(
            boundary: :avatar, prefix: "store", rails_env: DEVELOPMENT,
          )
        end

      assert_match(/unregistered object-storage boundary/, error.message)
    end
  end

  test "production staging selects the S3-compatible endpoint" do
    with_env("DEPLOYMENT_TIER" => "staging") do
      assert_equal :s3_compatible, ObjectStorage::ShrineConfiguration.mode(PRODUCTION)
    end
  end

  test "real production selects AWS S3" do
    with_env("DEPLOYMENT_TIER" => "production") do
      assert_equal :s3, ObjectStorage::ShrineConfiguration.mode(PRODUCTION)
    end
  end

  test "production requires an explicit deployment tier" do
    with_env("DEPLOYMENT_TIER" => nil) do
      error = assert_raises(KeyError) { ObjectStorage::ShrineConfiguration.mode(PRODUCTION) }

      assert_match(/DEPLOYMENT_TIER/, error.message)
    end
  end

  test "production refuses an unknown deployment tier" do
    with_env("DEPLOYMENT_TIER" => "preview") do
      error = assert_raises(ArgumentError) { ObjectStorage::ShrineConfiguration.mode(PRODUCTION) }

      assert_match(/DEPLOYMENT_TIER/, error.message)
      assert_match(/preview/, error.message)
    end
  end

  test "test remains in memory even when staging S3 variables are present" do
    with_s3_compatible_configuration do
      with_env("DEPLOYMENT_TIER" => "staging") do
        assert_equal :memory, ObjectStorage::ShrineConfiguration.mode(TEST)
      end
    end
  end

  # `mode` is the only thing that decides which backend is built, so a mode neither builder knows
  # about has to stop rather than fall through to a default. Both builders are pinned: `storages`
  # runs at boot and `build_storage` runs per boundary, and a silent default in either is how an
  # upload ends up somewhere nobody chose.
  test "a mode neither storage builder knows about is refused rather than defaulted" do
    ObjectStorage::ShrineConfiguration.stub(:mode, :quantum_tape) do
      %i(storages build_storage).each do |builder|
        error =
          assert_raises(ArgumentError, "#{builder} must refuse an unknown mode") do
            if builder == :storages
              ObjectStorage::ShrineConfiguration.storages(DEVELOPMENT)
            else
              ObjectStorage::ShrineConfiguration.build_storage(
                boundary: :avatar, prefix: "store", rails_env: DEVELOPMENT,
              )
            end
          end

        assert_equal "unsupported object-storage mode", error.message
      end
    end
  end

  # The production path. `s3_storage` takes its region from configuration and its credentials from
  # the AWS provider chain, and it must not be handed an endpoint -- that is the S3-compatible
  # path, and accepting it in production would point production uploads at another operator's
  # object store.
  test "the production s3 storage is built from the configured region and carries no endpoint" do
    with_env(
      "OBJECT_STORAGE_ENDPOINT" => nil,
      "OBJECT_STORAGE_REGION" => "jp-north-1",
      "AWS_ACCESS_KEY_ID" => "test-access-key",
      "AWS_SECRET_ACCESS_KEY" => "test-secret-key",
      "AWS_EC2_METADATA_DISABLED" => "true",
    ) do
      storage = ObjectStorage::ShrineConfiguration.s3_storage(bucket: "umaxica-test-bucket", prefix: "store")

      assert_kind_of Shrine::Storage::S3, storage
      assert_equal "umaxica-test-bucket", storage.bucket.name
      assert_equal "store", storage.prefix
      assert_equal "jp-north-1", storage.client.config.region
    end
  end

  test "an endpoint set on the production path is refused instead of being honoured" do
    with_env(
      "OBJECT_STORAGE_ENDPOINT" => "https://objects.example",
      "OBJECT_STORAGE_REGION" => "jp-north-1",
    ) do
      error =
        assert_raises(ArgumentError) do
          ObjectStorage::ShrineConfiguration.s3_storage(bucket: "umaxica-test-bucket", prefix: "store")
        end

      assert_match(/OBJECT_STORAGE_ENDPOINT must not be set in production/, error.message)
    end
  end

  test "an environment object storage does not serve is refused by name" do
    assert_raises(ArgumentError) do
      ObjectStorage::ShrineConfiguration.mode(ActiveSupport::StringInquirer.new("staging"))
    end
  end
end

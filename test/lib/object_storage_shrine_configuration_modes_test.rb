# typed: false
# frozen_string_literal: true

require "test_helper"

# Object storage resolves to a different backend per environment, and the
# development environment picks between a local directory and an S3-compatible
# endpoint depending on whether that endpoint is configured. Production is not
# exercised here -- it resolves to S3 and is asserted elsewhere -- but the two
# development branches decide where a developer's uploads actually land, so both
# are pinned.
class ObjectStorageShrineConfigurationModesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  DEVELOPMENT = ActiveSupport::StringInquirer.new("development")

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

  test "development without an s3-compatible endpoint writes to the local directory" do
    without_s3_compatible_configuration do
      assert_equal :local_filesystem, ObjectStorage::ShrineConfiguration.mode(DEVELOPMENT)

      storage = ObjectStorage::ShrineConfiguration.build_storage(
        boundary: :avatar, prefix: "store", rails_env: DEVELOPMENT,
      )

      assert_kind_of Shrine::Storage::FileSystem, storage
    end
  end

  test "development with an s3-compatible endpoint configured uses that endpoint" do
    with_s3_compatible_configuration do
      assert_equal :s3_compatible, ObjectStorage::ShrineConfiguration.mode(DEVELOPMENT)

      # No boundary is registered, so every bucket lookup is refused by name --
      # a deployment is never asked for a bucket it has not declared.
      error = assert_raises(ArgumentError) do
        ObjectStorage::ShrineConfiguration.build_storage(
          boundary: :avatar, prefix: "store", rails_env: DEVELOPMENT,
        )
      end

      assert_match(/unregistered object-storage boundary/, error.message)
    end
  end

  test "an environment object storage does not serve is refused by name" do
    assert_raises(ArgumentError) do
      ObjectStorage::ShrineConfiguration.mode(ActiveSupport::StringInquirer.new("staging"))
    end
  end
end

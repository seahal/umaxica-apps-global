# typed: false
# frozen_string_literal: true

require "test_helper"
require "shrine/storage/file_system"

# Security regression guards for object-storage configuration.
#
# The defect these pin: the previous initializer branched only on Rails.env.test?
# and sent every other environment, production included, to
# Shrine::Storage::FileSystem.new("public", prefix: "uploads") -- inside the
# publicly served web root.
class ShrineConfigurationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "the test environment uses in-memory storage for cache and store" do
    storages = ObjectStorage::ShrineConfiguration.storages(ActiveSupport::StringInquirer.new("test"))

    assert_instance_of(Shrine::Storage::Memory, storages.fetch(:cache))
    assert_instance_of(Shrine::Storage::Memory, storages.fetch(:store))
  end

  test "no configured storage writes into the public web root" do
    public_root = Rails.public_path.to_s

    offenders =
      Shrine.storages.filter_map do |name, storage|
        next unless storage.is_a?(Shrine::Storage::FileSystem)
        next unless storage.directory.to_s.start_with?(public_root)

        "#{name.inspect} -> #{storage.directory}"
      end

    assert_empty(offenders, "storages write into the public web root: #{offenders.join(", ")}")
  end

  test "production resolves to S3 and never to the file system" do
    production = ActiveSupport::StringInquirer.new("production")

    assert_equal(:s3, ObjectStorage::ShrineConfiguration.mode(production))
    assert_empty(ObjectStorage::ShrineConfiguration.storages(production))
  end

  test "development without S3-compatible configuration stays outside the public web root" do
    development = ActiveSupport::StringInquirer.new("development")
    # The _FILE variants must go too: credentials arrive as mounted secrets, so
    # deleting only the plain names would leave the set partially configured.
    names = %w(
      OBJECT_STORAGE_ENDPOINT OBJECT_STORAGE_REGION OBJECT_STORAGE_ACCESS_KEY_ID
      OBJECT_STORAGE_SECRET_ACCESS_KEY OBJECT_STORAGE_FORCE_PATH_STYLE
      OBJECT_STORAGE_ACCESS_KEY_ID_FILE OBJECT_STORAGE_SECRET_ACCESS_KEY_FILE
    )
    saved = names.index_with { |name| ENV[name] }
    names.each { |name| ENV.delete(name) }

    assert_equal(:local_filesystem, ObjectStorage::ShrineConfiguration.mode(development))

    storages = ObjectStorage::ShrineConfiguration.storages(development)
    storages.each_value do |storage|
      assert_instance_of(Shrine::Storage::FileSystem, storage)
      assert_not(storage.directory.to_s.start_with?(Rails.public_path.to_s))
    end
  ensure
    saved&.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end

  test "the local development root is absolute and outside the public web root" do
    root = ObjectStorage::ShrineConfiguration.local_root

    # A relative root would resolve against the process working directory, so a
    # process started elsewhere would write uploads somewhere unintended.
    assert_predicate(Pathname.new(root), :absolute?, "local root must be absolute, got #{root}")
    assert_equal(Rails.root.join("tmp/uploads").to_s, root)
    assert_not(root.start_with?(Rails.public_path.to_s))
  end

  test "verifying registered boundaries is a no-op while none are registered" do
    assert_empty(ObjectStorage::Boundary.keys)
    assert_nothing_raised { ObjectStorage::ShrineConfiguration.verify_registered_boundaries! }
  end

  test "verifying registered boundaries surfaces missing configuration at boot" do
    original = ObjectStorage::Boundary::REGISTRY
    Kernel.silence_warnings { ObjectStorage::Boundary.const_set(:REGISTRY, { demo: "DEMO" }.freeze) }
    ENV.delete("OBJECT_STORAGE_BUCKET_DEMO")

    # Without this eager pass the missing bucket would not surface until the
    # first upload, long after boot.
    assert_raises(KeyError) do
      ObjectStorage::ShrineConfiguration.verify_registered_boundaries!(
        ActiveSupport::StringInquirer.new("production"),
      )
    end
  ensure
    Kernel.silence_warnings { ObjectStorage::Boundary.const_set(:REGISTRY, original) }
    ObjectStorage::ShrineConfiguration::STORAGE_CACHE.clear
  end

  test "an unsupported Rails environment raises rather than guessing a storage" do
    error =
      assert_raises(ArgumentError) do
        ObjectStorage::ShrineConfiguration.mode(ActiveSupport::StringInquirer.new("staging"))
      end

    assert_match("staging", error.message)
  end

  test "production refuses an endpoint override" do
    ENV["OBJECT_STORAGE_ENDPOINT"] = "http://rustfs:9000"
    ENV["OBJECT_STORAGE_REGION"] = "us-east-1"

    error =
      assert_raises(ArgumentError) do
        ObjectStorage::ShrineConfiguration.s3_storage(bucket: "umaxica-avatar", prefix: "store")
      end

    assert_match("OBJECT_STORAGE_ENDPOINT", error.message)
  ensure
    ENV.delete("OBJECT_STORAGE_ENDPOINT")
    ENV.delete("OBJECT_STORAGE_REGION")
  end

  test "production S3 storage requires a region" do
    ENV.delete("OBJECT_STORAGE_ENDPOINT")
    ENV.delete("OBJECT_STORAGE_REGION")

    assert_raises(KeyError) do
      ObjectStorage::ShrineConfiguration.s3_storage(bucket: "umaxica-avatar", prefix: "store")
    end
  end

  test "an unregistered boundary resolves to no storage so Shrine fails closed" do
    assert_nil(ObjectStorage::ShrineConfiguration.dynamic("not_a_boundary", "store"))
  end

  test "a resolved boundary storage is memoized across lookups" do
    original = ObjectStorage::Boundary::REGISTRY
    Kernel.silence_warnings { ObjectStorage::Boundary.const_set(:REGISTRY, { demo: "DEMO" }.freeze) }

    first = ObjectStorage::ShrineConfiguration.dynamic("demo", "store")
    second = ObjectStorage::ShrineConfiguration.dynamic("demo", "store")

    # Shrine's dynamic_storage plugin calls the resolver on every find_storage
    # lookup, so an unmemoized resolver would hand back a new, empty store each
    # time and lose already-uploaded files.
    assert_same(first, second)
  ensure
    Kernel.silence_warnings { ObjectStorage::Boundary.const_set(:REGISTRY, original) }
    ObjectStorage::ShrineConfiguration::STORAGE_CACHE.clear
  end

  test "an unknown storage role resolves to no storage" do
    assert_nil(ObjectStorage::ShrineConfiguration.dynamic("avatar", "archive"))
  end

  test "requesting an unregistered storage name raises Shrine::MissingStorage" do
    assert_raises(Shrine::MissingStorage) { Shrine.find_storage("not_a_boundary_store") }
  end
end

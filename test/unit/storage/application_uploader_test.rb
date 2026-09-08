# typed: false
# frozen_string_literal: true

require "test_helper"

class ApplicationUploaderTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "an uploader without a declared boundary refuses to select a storage" do
    uploader = Class.new(ApplicationUploader)

    assert_raises(ApplicationUploader::BoundaryNotDeclaredError) { uploader.storage_boundary! }
  end

  test "storage names derive from the declared boundary alone" do
    uploader = Class.new(ApplicationUploader) { def self.storage_boundary = :demo }
    attacher = uploader::Attacher.new

    assert_equal(:demo_cache, attacher.cache_key)
    assert_equal(:demo_store, attacher.store_key)
  end

  test "the location is built from the owner public_id and a random component" do
    uploader = Class.new(ApplicationUploader) { def self.storage_boundary = :demo }
    record = Avatar.new(public_id: "S6TfLpH2QwErTyUiOpAsZ")

    location = uploader.new(:store).generate_location(nil, record: record, name: :image)

    assert_equal(%w(avatar S6TfLpH2QwErTyUiOpAsZ image), location.split("/").first(3))
    assert_match(/\A[0-9a-f]{32}\z/, location.split("/").last)
  end

  test "each generated location is unique so ORM dirty tracking detects the change" do
    uploader = Class.new(ApplicationUploader) { def self.storage_boundary = :demo }
    record = Avatar.new(public_id: "S6TfLpH2QwErTyUiOpAsZ")
    instance = uploader.new(:store)

    first = instance.generate_location(nil, record: record, name: :image)
    second = instance.generate_location(nil, record: record, name: :image)

    assert_not_equal(first, second)
  end

  test "a record without a public_id raises instead of sharing a namespace" do
    uploader = Class.new(ApplicationUploader) { def self.storage_boundary = :demo }
    record = Struct.new(:public_id).new(nil)

    assert_raises(ApplicationUploader::MissingPublicIdError) do
      uploader.new(:store).generate_location(nil, record: record, name: :image)
    end
  end

  test "location generation does not require ambient request state" do
    uploader = Class.new(ApplicationUploader) { def self.storage_boundary = :demo }
    record = Avatar.new(public_id: "S6TfLpH2QwErTyUiOpAsZ")

    Actor.reset

    location = uploader.new(:store).generate_location(nil, record: record, name: :image)

    assert_includes(location, "S6TfLpH2QwErTyUiOpAsZ")
  end

  test "the original filename never contributes to the location" do
    uploader = Class.new(ApplicationUploader) { def self.storage_boundary = :demo }
    record = Avatar.new(public_id: "S6TfLpH2QwErTyUiOpAsZ")
    io = Shrine.upload(StringIO.new("body"), :store, metadata: { "filename" => "secret-name.png" })

    location = uploader.new(:store).generate_location(io, record: record, name: :image)

    assert_not_includes(location, "secret-name")
    assert_not_includes(location, ".png")
  end
end

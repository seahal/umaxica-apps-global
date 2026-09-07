# typed: false
# frozen_string_literal: true

require "test_helper"

class ObjectStorageBoundaryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "registered boundaries match the attachment-owning domains" do
    assert_equal(%i(avatar publishing), ObjectStorage::Boundary.keys)
  end

  test "an unregistered boundary raises and names the boundary" do
    assert_not(ObjectStorage::Boundary.registered?(:not_a_boundary))

    error = assert_raises(ArgumentError) { ObjectStorage::Boundary.bucket_variable(:not_a_boundary) }
    assert_match("not_a_boundary", error.message)
  end

  test "a registered boundary resolves to its own bucket variable" do
    original = ObjectStorage::Boundary::REGISTRY
    Kernel.silence_warnings { ObjectStorage::Boundary.const_set(:REGISTRY, { avatar: "AVATAR" }.freeze) }
    ENV["OBJECT_STORAGE_BUCKET_AVATAR"] = "umaxica-avatar"

    assert(ObjectStorage::Boundary.registered?(:avatar))
    assert_equal("OBJECT_STORAGE_BUCKET_AVATAR", ObjectStorage::Boundary.bucket_variable(:avatar))
    assert_equal("umaxica-avatar", ObjectStorage::Boundary.bucket(:avatar))
  ensure
    Kernel.silence_warnings { ObjectStorage::Boundary.const_set(:REGISTRY, original) }
    ENV.delete("OBJECT_STORAGE_BUCKET_AVATAR")
  end

  test "a registered boundary with no configured bucket raises" do
    original = ObjectStorage::Boundary::REGISTRY
    Kernel.silence_warnings { ObjectStorage::Boundary.const_set(:REGISTRY, { avatar: "AVATAR" }.freeze) }
    ENV.delete("OBJECT_STORAGE_BUCKET_AVATAR")

    assert_raises(KeyError) { ObjectStorage::Boundary.bucket(:avatar) }
  ensure
    Kernel.silence_warnings { ObjectStorage::Boundary.const_set(:REGISTRY, original) }
  end
end

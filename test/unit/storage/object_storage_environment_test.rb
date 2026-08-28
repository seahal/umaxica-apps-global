# typed: false
# frozen_string_literal: true

require "test_helper"

class ObjectStorageEnvironmentTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "fetch returns the inline variable when no file is configured" do
    ENV["OBJECT_STORAGE_TEST_VALUE"] = "inline-value"

    assert_equal("inline-value", ObjectStorage::Environment.fetch("OBJECT_STORAGE_TEST_VALUE"))
  ensure
    ENV.delete("OBJECT_STORAGE_TEST_VALUE")
  end

  test "fetch raises for a missing required variable instead of returning nil" do
    ENV.delete("OBJECT_STORAGE_TEST_VALUE")

    assert_raises(KeyError) { ObjectStorage::Environment.fetch("OBJECT_STORAGE_TEST_VALUE") }
  end

  test "fetch raises for a blank variable" do
    ENV["OBJECT_STORAGE_TEST_VALUE"] = ""

    error = assert_raises(ArgumentError) { ObjectStorage::Environment.fetch("OBJECT_STORAGE_TEST_VALUE") }
    assert_match("OBJECT_STORAGE_TEST_VALUE", error.message)
  ensure
    ENV.delete("OBJECT_STORAGE_TEST_VALUE")
  end

  test "a configured secret file takes precedence over the inline variable" do
    file = Tempfile.new("object-storage-secret")
    file.write("  from-file  \n")
    file.close
    ENV["OBJECT_STORAGE_ACCESS_KEY_ID"] = "from-inline"
    ENV["OBJECT_STORAGE_ACCESS_KEY_ID_FILE"] = file.path

    assert_equal("from-file", ObjectStorage::Environment.fetch("OBJECT_STORAGE_ACCESS_KEY_ID"))
  ensure
    ENV.delete("OBJECT_STORAGE_ACCESS_KEY_ID")
    ENV.delete("OBJECT_STORAGE_ACCESS_KEY_ID_FILE")
    file&.unlink
  end

  test "an unreadable secret file raises instead of falling back to the inline variable" do
    ENV["OBJECT_STORAGE_ACCESS_KEY_ID"] = "from-inline"
    ENV["OBJECT_STORAGE_ACCESS_KEY_ID_FILE"] = "/nonexistent/object-storage-secret"

    assert_raises(Errno::ENOENT) { ObjectStorage::Environment.fetch("OBJECT_STORAGE_ACCESS_KEY_ID") }
  ensure
    ENV.delete("OBJECT_STORAGE_ACCESS_KEY_ID")
    ENV.delete("OBJECT_STORAGE_ACCESS_KEY_ID_FILE")
  end

  test "fetch_boolean accepts only exactly true or false" do
    ENV["OBJECT_STORAGE_TEST_FLAG"] = "true"

    assert_same(true, ObjectStorage::Environment.fetch_boolean("OBJECT_STORAGE_TEST_FLAG"))

    ENV["OBJECT_STORAGE_TEST_FLAG"] = "false"

    assert_same(false, ObjectStorage::Environment.fetch_boolean("OBJECT_STORAGE_TEST_FLAG"))

    ENV["OBJECT_STORAGE_TEST_FLAG"] = "TRUE"
    assert_raises(ArgumentError) { ObjectStorage::Environment.fetch_boolean("OBJECT_STORAGE_TEST_FLAG") }

    ENV["OBJECT_STORAGE_TEST_FLAG"] = "1"
    assert_raises(ArgumentError) { ObjectStorage::Environment.fetch_boolean("OBJECT_STORAGE_TEST_FLAG") }
  ensure
    ENV.delete("OBJECT_STORAGE_TEST_FLAG")
  end

  test "configured? raises on a partially configured set instead of silently opting out" do
    ENV["OBJECT_STORAGE_TEST_ONE"] = "set"
    ENV.delete("OBJECT_STORAGE_TEST_TWO")

    error =
      assert_raises(ArgumentError) do
        ObjectStorage::Environment.configured?(%w(OBJECT_STORAGE_TEST_ONE OBJECT_STORAGE_TEST_TWO))
      end

    # A half-configured set always means a typo or a missing secret mount.
    # Selecting a different storage instead would hide that.
    assert_match("OBJECT_STORAGE_TEST_ONE", error.message)
    assert_match("OBJECT_STORAGE_TEST_TWO", error.message)
  ensure
    ENV.delete("OBJECT_STORAGE_TEST_ONE")
    ENV.delete("OBJECT_STORAGE_TEST_TWO")
  end

  test "configured? is true only when every variable in the set is present" do
    ENV["OBJECT_STORAGE_TEST_ONE"] = "set"
    ENV["OBJECT_STORAGE_TEST_TWO"] = "set"

    assert(ObjectStorage::Environment.configured?(%w(OBJECT_STORAGE_TEST_ONE OBJECT_STORAGE_TEST_TWO)))

    ENV.delete("OBJECT_STORAGE_TEST_ONE")
    ENV.delete("OBJECT_STORAGE_TEST_TWO")

    assert_not(ObjectStorage::Environment.configured?(%w(OBJECT_STORAGE_TEST_ONE OBJECT_STORAGE_TEST_TWO)))
  ensure
    ENV.delete("OBJECT_STORAGE_TEST_ONE")
    ENV.delete("OBJECT_STORAGE_TEST_TWO")
  end

  test "configured? reports presence without raising" do
    ENV.delete("OBJECT_STORAGE_TEST_VALUE")

    assert_not(ObjectStorage::Environment.configured?(%w(OBJECT_STORAGE_TEST_VALUE)))

    ENV["OBJECT_STORAGE_TEST_VALUE"] = "present"

    assert(ObjectStorage::Environment.configured?(%w(OBJECT_STORAGE_TEST_VALUE)))

    ENV["OBJECT_STORAGE_TEST_VALUE"] = ""

    assert_not(ObjectStorage::Environment.configured?(%w(OBJECT_STORAGE_TEST_VALUE)))
  ensure
    ENV.delete("OBJECT_STORAGE_TEST_VALUE")
  end
end

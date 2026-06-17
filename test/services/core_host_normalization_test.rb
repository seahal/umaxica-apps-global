# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreHostNormalizationTest < ActiveSupport::TestCase
  test "normalizes a standard host" do
    assert_equal "example.com", CoreHostNormalization.normalize("https://Example.Com/")
  end

  test "returns nil for blank input" do
    assert_nil CoreHostNormalization.normalize(nil)
    assert_nil CoreHostNormalization.normalize("")
    assert_nil CoreHostNormalization.normalize("   ")
  end

  test "falls back to host extraction when URI parsing fails" do
    assert_equal "example.com", CoreHostNormalization.normalize("example.com:8080/path")
  end

  test "returns nil for unparseable host with invalid URI" do
    result = CoreHostNormalization.normalize("\x00")

    assert_nil result
  end

  test "rescues from URI parse failure and falls back to host extraction" do
    result = CoreHostNormalization.normalize("foo bar")

    assert_equal "foo bar", result
  end
end

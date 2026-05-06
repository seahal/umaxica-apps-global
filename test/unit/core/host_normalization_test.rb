# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreHostNormalizationTest < ActiveSupport::TestCase
  test "normalize returns nil for blank string" do
    assert_nil Core::HostNormalization.normalize("")
  end

  test "normalize returns nil for nil" do
    assert_nil Core::HostNormalization.normalize(nil)
  end

  test "normalize returns nil for whitespace-only string" do
    assert_nil Core::HostNormalization.normalize("   ")
  end

  test "normalize downcases the host" do
    assert_equal "example.com", Core::HostNormalization.normalize("EXAMPLE.COM")
  end

  test "normalize strips whitespace" do
    assert_equal "example.com", Core::HostNormalization.normalize("  example.com  ")
  end

  test "normalize removes trailing dot" do
    assert_equal "example.com", Core::HostNormalization.normalize("example.com.")
  end

  test "normalize extracts host from URL" do
    assert_equal "example.com", Core::HostNormalization.normalize("https://example.com")
  end

  test "normalize handles plain host without scheme" do
    assert_equal "id.app.localhost", Core::HostNormalization.normalize("id.app.localhost")
  end

  test "normalize handles subdomain hosts" do
    assert_equal "sub.example.com", Core::HostNormalization.normalize("sub.example.com")
  end

  test "normalize removes port from URL" do
    assert_equal "example.com", Core::HostNormalization.normalize("https://example.com:443")
  end

  test "normalize handles localhost" do
    assert_equal "localhost", Core::HostNormalization.normalize("localhost")
  end

  test "normalize handles http scheme" do
    assert_equal "example.com", Core::HostNormalization.normalize("http://example.com")
  end

  test "parsed_host extracts host from https URL" do
    assert_equal "example.com", Core::HostNormalization.send(:parsed_host, "https://example.com/path")
  end

  test "parsed_host extracts host from http URL" do
    assert_equal "example.com", Core::HostNormalization.send(:parsed_host, "http://example.com:8080/path")
  end

  test "parsed_host adds scheme to plain host" do
    assert_equal "example.com", Core::HostNormalization.send(:parsed_host, "example.com")
  end

  test "parsed_host returns nil for invalid URI" do
    assert_nil Core::HostNormalization.send(:parsed_host, "://invalid")
  end

  test "fallback_host strips scheme and extracts host" do
    assert_equal "example.com", Core::HostNormalization.send(:fallback_host, "https://example.com/path")
  end

  test "fallback_host removes port" do
    assert_equal "example.com", Core::HostNormalization.send(:fallback_host, "example.com:8080")
  end
end

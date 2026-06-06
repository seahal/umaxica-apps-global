# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpRtReturnPolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "normalize_origin returns nil for invalid URI" do
    assert_nil JumpRtReturnPolicy.normalize_origin("not a url")
  end

  test "normalize_origin returns nil for non-http scheme" do
    assert_nil JumpRtReturnPolicy.normalize_origin("ftp://example.com")
  end

  test "normalize_origin returns nil for URI with userinfo" do
    assert_nil JumpRtReturnPolicy.normalize_origin("https://user:pass@www.umaxica.app")
  end

  test "normalize_origin normalizes https origin" do
    result = JumpRtReturnPolicy.normalize_origin("https://www.umaxica.app")

    assert_equal "https://www.umaxica.app", result
  end

  test "normalize_origin normalizes http origin" do
    result = JumpRtReturnPolicy.normalize_origin("http://example.com")

    assert_equal "http://example.com", result
  end

  test "normalize_origin downcases host" do
    result = JumpRtReturnPolicy.normalize_origin("https://WWW.UMAXICA.APP")

    assert_equal "https://www.umaxica.app", result
  end

  test "normalize_origin includes non-default port" do
    result = JumpRtReturnPolicy.normalize_origin("https://www.umaxica.app:8443")

    assert_equal "https://www.umaxica.app:8443", result
  end

  test "normalize_origin omits default https port" do
    result = JumpRtReturnPolicy.normalize_origin("https://www.umaxica.app:443")

    assert_equal "https://www.umaxica.app", result
  end

  test "normalize_origin omits default http port" do
    result = JumpRtReturnPolicy.normalize_origin("http://example.com:80")

    assert_equal "http://example.com", result
  end

  test "normalize_origin returns nil for blank host" do
    assert_nil JumpRtReturnPolicy.normalize_origin("https://")
  end

  test "allowed_source returns true for valid source matching destination" do
    assert JumpRtReturnPolicy.allowed_source?(
      destination_origin: "https://www.umaxica.app",
      source: "https://id.umaxica.app",
    )
  end

  test "allowed_source returns false for unauthorized source" do
    assert_not JumpRtReturnPolicy.allowed_source?(
      destination_origin: "https://www.umaxica.app",
      source: "https://evil.example.com",
    )
  end

  test "allowed_source returns false when destination origin is unknown" do
    assert_not JumpRtReturnPolicy.allowed_source?(
      destination_origin: "https://unknown.example.com",
      source: "https://id.umaxica.app",
    )
  end

  test "default_port_for returns 443 for https" do
    assert_equal 443, JumpRtReturnPolicy.default_port_for("https")
  end

  test "default_port_for returns 80 for http" do
    assert_equal 80, JumpRtReturnPolicy.default_port_for("http")
  end

  test "allowed_sources includes hardcoded production origins" do
    sources = JumpRtReturnPolicy.allowed_sources

    assert_includes sources.keys, "https://www.umaxica.app"
    assert_includes sources["https://www.umaxica.app"], "https://id.umaxica.app"
  end

  test "core destinations allow matching idp sources" do
    assert JumpRtReturnPolicy.allowed_source?(
      destination_origin: "https://www.jp.umaxica.app",
      source: "https://id.umaxica.app",
    )
    assert JumpRtReturnPolicy.allowed_source?(
      destination_origin: "https://www.jp.umaxica.com",
      source: "https://id.umaxica.com",
    )
    assert JumpRtReturnPolicy.allowed_source?(
      destination_origin: "https://www.jp.umaxica.org",
      source: "https://id.umaxica.org",
    )
  end

  test "core destinations reject cross surface idp sources" do
    assert_not JumpRtReturnPolicy.allowed_source?(
      destination_origin: "https://www.jp.umaxica.app",
      source: "https://id.umaxica.org",
    )
  end
end

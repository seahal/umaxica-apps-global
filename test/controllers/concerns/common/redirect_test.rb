# typed: false
# frozen_string_literal: true

require "test_helper"

class Common::RedirectTest < ActiveSupport::TestCase
  test "private helper methods are not public on including controller" do
    # Define a test controller that includes the concern
    test_controller =
      Class.new(ApplicationController) do
        include Common::Redirect
      end

    controller = test_controller.new

    # These methods should be private, not public
    assert_includes controller.private_methods, :safe_internal_path
    assert_not controller.public_methods.include?(:safe_internal_path)

    assert_includes controller.private_methods, :safe_redirect_to
    assert_not controller.public_methods.include?(:safe_redirect_to)

    assert_includes controller.private_methods, :safe_redirect_back_or_to
    assert_not controller.public_methods.include?(:safe_redirect_back_or_to)

    assert_includes controller.private_methods, :generate_redirect_url
    assert_not controller.public_methods.include?(:generate_redirect_url)

    assert_includes controller.private_methods, :jump_to_generated_url
    assert_not controller.public_methods.include?(:jump_to_generated_url)
  end

  test "allowed_hosts is public on including controller" do
    test_controller =
      Class.new(ApplicationController) do
        include Common::Redirect
      end

    controller = test_controller.new

    # allowed_hosts should remain public (for diagnostics/auditing)
    assert_respond_to controller, :allowed_hosts
    assert_not controller.private_methods.include?(:allowed_hosts)
  end

  test "normalize_host returns nil for blank values" do
    assert_nil Common::Redirect.normalize_host(nil)
    assert_nil Common::Redirect.normalize_host("")
    assert_nil Common::Redirect.normalize_host("   ")
  end

  test "normalize_host extracts host from URL" do
    assert_equal "example.com", Common::Redirect.normalize_host("https://example.com/path")
    assert_equal "example.com", Common::Redirect.normalize_host("http://example.com")
    assert_equal "example.com", Common::Redirect.normalize_host("example.com/path")
  end

  test "normalize_host handles invalid URIs" do
    assert_equal "not a url", Common::Redirect.normalize_host("not a url")
  end

  test "normalize_host downcases host" do
    assert_equal "example.com", Common::Redirect.normalize_host("HTTPS://EXAMPLE.COM")
  end

  # --- Open-redirect regression guards -------------------------------------
  #
  # safe_internal_path / safe_return_path are the security boundary that keeps
  # user-supplied return targets from redirecting off-site. These tests pin the
  # rejection contract so a future refactor cannot silently widen it.

  def redirect_helper
    @redirect_helper ||=
      Class.new(ApplicationController) { include Common::Redirect }.new
  end

  test "safe_internal_path rejects blank and control-character input" do
    assert_nil redirect_helper.send(:safe_internal_path, nil)
    assert_nil redirect_helper.send(:safe_internal_path, "")
    assert_nil redirect_helper.send(:safe_internal_path, "/dash\nboard")
    assert_nil redirect_helper.send(:safe_internal_path, "/dash\tboard")
    assert_nil redirect_helper.send(:safe_internal_path, :dashboard)
  end

  test "safe_internal_path rejects absolute, scheme, host, and userinfo targets" do
    assert_nil redirect_helper.send(:safe_internal_path, "https://evil.example/path")
    assert_nil redirect_helper.send(:safe_internal_path, "//evil.example/path")
    assert_nil redirect_helper.send(:safe_internal_path, "http://user:pass@evil.example/")
    assert_nil redirect_helper.send(:safe_internal_path, "javascript:alert(1)")
    assert_nil redirect_helper.send(:safe_internal_path, "relative/path")
  end

  test "safe_internal_path rejects fragments and ambiguous encoded path bytes" do
    assert_nil redirect_helper.send(:safe_internal_path, "/#fragment")
    assert_nil redirect_helper.send(:safe_internal_path, "/dashboard#fragment")
    assert_nil redirect_helper.send(:safe_internal_path, "/dash\\board")
    assert_nil redirect_helper.send(:safe_internal_path, "/%2F%2Fevil.example")
    assert_nil redirect_helper.send(:safe_internal_path, "/%5Cevil")
    assert_nil redirect_helper.send(:safe_internal_path, "/%00")
    assert_nil redirect_helper.send(:safe_internal_path, "/%0d%0aLocation:%20https://evil.example")
  end

  test "safe_internal_path accepts clean internal paths and preserves query" do
    assert_equal "/dashboard", redirect_helper.send(:safe_internal_path, "/dashboard")
    assert_equal "/dashboard?a=1&b=2", redirect_helper.send(:safe_internal_path, "/dashboard?a=1&b=2")
  end

  test "safe_return_path rejects external hosts when no host is allowed" do
    assert_nil redirect_helper.send(:safe_return_path, :dashboard)
    assert_nil redirect_helper.send(:safe_return_path, "https://evil.example/path")
    assert_nil redirect_helper.send(:safe_return_path, "//evil.example/path")
  end

  test "safe_return_path rejects non-http schemes and userinfo even for allowed hosts" do
    allowed = ["trusted.example.com"]

    assert_nil redirect_helper.send(:safe_return_path, "ftp://trusted.example.com/x", allowed_hosts: allowed)
    assert_nil redirect_helper.send(:safe_return_path, "javascript:alert(1)", allowed_hosts: allowed)
    assert_nil redirect_helper.send(:safe_return_path, "https://u:p@trusted.example.com/x", allowed_hosts: allowed)
  end

  test "safe_return_path is path target only and ignores legacy allowed hosts" do
    allowed = ["trusted.example.com"]

    assert_nil redirect_helper.send(
      :safe_return_path, "https://trusted.example.com/welcome?ref=1",
      allowed_hosts: allowed,
    )
  end

  test "generate_redirect_url drops off-site targets and round-trips internal ones" do
    assert_nil redirect_helper.send(:generate_redirect_url, "https://evil.example/x")

    encoded = redirect_helper.send(:generate_redirect_url, "/safe?a=1")

    assert_not_nil encoded
    assert_equal "/safe?a=1", redirect_helper.send(:safe_return_path, Base64.urlsafe_decode64(encoded))
  end
end

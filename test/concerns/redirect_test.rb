# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class RedirectTest < ActiveSupport::TestCase
  include CommonRedirect

  setup do
    @original_env = ENV.to_h
    ENV["CORPORATE_URL"] = "https://com.localhost"
    ENV["SERVICE_URL"] = "https://app.localhost"
    ENV["STAFF_URL"] = "https://org.localhost"
    ENV["NETWORK_URL"] = "https://net.localhost"
    ENV["DEV_URL"] = "https://dev.localhost"
  end

  teardown do
    ENV.clear
    ENV.update(@original_env)
  end

  test "generate_redirect_url should reject absolute URLs" do
    encoded = generate_redirect_url("https://app.localhost/test")

    assert_nil encoded
  end

  test "generate_redirect_url should reject non-path strings" do
    encoded = generate_redirect_url("not a valid uri")

    assert_nil encoded
  end

  test "generate_redirect_url should encode absolute internal paths" do
    encoded = generate_redirect_url("/dashboard?x=1")

    assert_not_nil encoded
    assert_equal "/dashboard?x=1", Base64.urlsafe_decode64(encoded)
  end

  test "generate_redirect_url should handle blank URLs" do
    encoded = generate_redirect_url("")

    assert_nil encoded

    encoded = generate_redirect_url(nil)

    assert_nil encoded
  end

  test "allowed_hosts uses simplified environment keys" do
    hosts = allowed_hosts

    assert_equal %w(com.localhost app.localhost org.localhost net.localhost dev.localhost), hosts
  end
end

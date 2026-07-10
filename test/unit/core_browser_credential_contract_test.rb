# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CoreBrowserCredentialContractTest < ActiveSupport::TestCase
  test "cookie options encode required core browser flags" do
    access = CoreBrowserCredentialContract.access_cookie_options(expires_at: 10.minutes.from_now)
    refresh = CoreBrowserCredentialContract.refresh_cookie_options(expires_at: 1.day.from_now)
    oidc = CoreBrowserCredentialContract.oidc_cookie_options(expires_at: 10.minutes.from_now)

    assert access.fetch(:secure)
    assert access.fetch(:httponly)
    assert_equal :strict, access.fetch(:same_site)
    assert_equal "/", access.fetch(:path)

    assert refresh.fetch(:secure)
    assert refresh.fetch(:httponly)
    assert_equal :strict, refresh.fetch(:same_site)
    assert_equal "/", refresh.fetch(:path)

    assert oidc.fetch(:secure)
    assert oidc.fetch(:httponly)
    assert_equal :lax, oidc.fetch(:same_site)
    assert_equal "/", oidc.fetch(:path)
  end

  test "native and side audiences are classified as non core browser" do
    assert CoreBrowserCredentialContract.native_or_side_audience?("aud" => ["palm-api"])
    assert CoreBrowserCredentialContract.native_or_side_audience?("aud" => ["side-service"])
    assert_not CoreBrowserCredentialContract.native_or_side_audience?(
      "aud" => [CoreBrowserCredentialContract::ACCESS_AUDIENCE],
    )
    assert_not CoreBrowserCredentialContract.native_or_side_audience?("aud" => ["port-api"])
  end
end

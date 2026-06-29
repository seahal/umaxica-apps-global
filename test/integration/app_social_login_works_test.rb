# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class AppSocialLoginWorksTest < ActionDispatch::IntegrationTest
  setup do
    https!
  end

  test "POST /social/google on app host redirects to Google OAuth" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL")

    post "/social/google"

    # Should redirect to Google OAuth (302) or OmniAuth failure
    assert_response :redirect
    assert_match %r{(google|social/failure)}, response.location
  end

  test "POST /social for org Google provider on app host is not registered" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL")

    post "/social/google_#{"org"}"

    assert_response :not_found
  end

  test "POST /social/apple on app host redirects to Apple Sign In" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL")

    post "/social/apple"

    # Should redirect to Apple (302) or OmniAuth failure
    assert_response :redirect
    assert_match %r{(apple|social/failure)}, response.location
  end
end

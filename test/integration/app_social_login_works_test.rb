# typed: false
# frozen_string_literal: true

require "test_helper"

class AppSocialLoginWorksTest < ActionDispatch::IntegrationTest
  setup do
    https!
  end

  test "POST /auth/google_app on :app host redirects to Google OAuth" do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    post "/auth/google_app"

    # Should redirect to Google OAuth (302) or OmniAuth failure
    assert_response :redirect
    assert_match %r{(google|auth/failure)}, response.location
  end

  test "POST /auth/google_org on :app host is handled" do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    post "/auth/google_org"

    # google_org is for staff, but should not 404 on app host
    assert_response :redirect
  end

  test "POST /auth/apple on :app host redirects to Apple Sign In" do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

    post "/auth/apple"

    # Should redirect to Apple (302) or OmniAuth failure
    assert_response :redirect
    assert_match %r{(apple|auth/failure)}, response.location
  end
end

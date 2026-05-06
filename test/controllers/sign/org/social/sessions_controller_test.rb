# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Social::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses, :staff_visibilities

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
  end

  test "start redirects to google oauth with valid provider" do
    get new_sign_org_social_session_path(provider: "google_org", ri: "jp")

    # Should redirect to /auth/google_org (OmniAuth entry point)
    assert_response :redirect
    assert_match %r{/auth/google_org}, response.location
  end

  test "start redirects to sign-in with alert for unsupported provider (apple)" do
    get new_sign_org_social_session_path(provider: "apple", ri: "jp")

    assert_redirected_to new_sign_org_in_path(ri: "jp")
    assert_equal I18n.t("sign.org.social.sessions.invalid_provider"), flash[:alert]
  end

  test "start redirects to sign-in with alert for unknown provider" do
    get new_sign_org_social_session_path(provider: "twitter", ri: "jp")

    assert_redirected_to new_sign_org_in_path(ri: "jp")
    assert_equal I18n.t("sign.org.social.sessions.invalid_provider"), flash[:alert]
  end
end

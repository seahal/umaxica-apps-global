# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Social::AuthenticationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_identity_statuses, :operator_visibilities

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
  end

  test "continue redirects to google oauth with valid provider" do
    post continue_sign_org_social_authentication_path(provider: "google_org", ri: "jp")

    assert_response :redirect
    assert_match %r{/auth/google_org}, response.location
  end

  test "start path is not routable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "/social/auth/google_org/start",
        method: :post,
      )
    end
  end

  test "continue redirects to sign-in with alert for unsupported provider (apple)" do
    post continue_sign_org_social_authentication_path(provider: "apple", ri: "jp")

    assert_redirected_to new_sign_org_in_path(ri: "jp")
    assert_equal I18n.t("sign.org.social.sessions.invalid_provider"), flash[:alert]
  end

  test "continue redirects to sign-in with alert for unknown provider" do
    post continue_sign_org_social_authentication_path(provider: "twitter", ri: "jp")

    assert_redirected_to new_sign_org_in_path(ri: "jp")
    assert_equal I18n.t("sign.org.social.sessions.invalid_provider"), flash[:alert]
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Social::AuthenticationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
  end

  test "continue redirects to google oauth with valid provider" do
    get sign_app_social_google_sign_in_path(provider: "google", ri: "jp")

    assert_response :redirect
    assert_match %r{/social/google\?state=}, response.location
  end

  test "continue stores only social ceremony transaction id in cookie session" do
    get sign_app_social_google_sign_in_path(provider: "google", ri: "jp")

    assert_response :redirect

    stored_value = session[SocialAuth::SOCIAL_CEREMONY_GRANT_SESSION_KEY]

    assert_predicate stored_value, :present?
    assert_nil session[SocialAuth::SOCIAL_PT_SESSION_KEY]
    assert_no_match(/\./, stored_value, "session must not store the signed social ceremony grant JWT")
    assert_operator stored_value.bytesize, :<, 80
    assert ClientSocialCeremonyTransaction.find_by(transaction_id: stored_value)
  end

  test "continue redirects to apple oauth with valid provider" do
    get sign_app_social_apple_sign_in_path(provider: "apple", ri: "jp")

    assert_response :redirect
    assert_match %r{/social/apple\?state=}, response.location
  end

  test "start path is not routable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "/social/google/sign/in",
        method: :post,
      )
    end
  end
end

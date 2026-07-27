# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::Social::AuthenticationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
  end

  test "continue renders a CSRF-protected POST form for Google authorization" do
    get new_auth_app_social_google_session_path(provider: "google", ri: "jp")

    assert_response :success
    assert_select "form#social-authorization-form[action='/social/google'][method='post'][data-turbo='false']", count: 1
    assert_select "form#social-authorization-form input[name='authenticity_token']", count: 1
  end

  test "continue stores only social ceremony transaction id in cookie session" do
    get new_auth_app_social_google_session_path(provider: "google", ri: "jp")

    assert_response :success

    stored_value = session[SocialAuth::SOCIAL_CEREMONY_GRANT_SESSION_KEY]

    assert_predicate stored_value, :present?
    assert_nil session[SocialAuth::SOCIAL_INTENT_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_STARTED_AT_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_PROVIDER_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_PT_SESSION_KEY]
    assert_no_match(/\./, stored_value, "session must not store the signed social ceremony grant JWT")
    assert_operator stored_value.bytesize, :<, 80
    assert ClientSocialCeremonyTransaction.find_by(transaction_id: stored_value)
  end

  test "continue issues a google sign-up flow for the sign-up entry" do
    assert_difference("ClientSignUpFlow.count", 1) do
      get new_auth_app_social_google_registration_path(provider: "google", ri: "jp")
    end

    assert_response :success
    assert_select "form#social-authorization-form[action='/social/google'][method='post']", count: 1

    cycle = ClientSignUpFlow.order(:created_at).last

    assert_equal "google", cycle.entry_method
    assert_equal "google", cycle.social_provider
    assert_equal "social_callback", cycle.step
    assert_equal cycle.public_id, session[:auth_app_up_sequence_id]
  end

  test "continue issues an apple sign-up flow for the sign-up entry" do
    assert_difference("ClientSignUpFlow.count", 1) do
      get new_auth_app_social_apple_registration_path(provider: "apple", ri: "jp")
    end

    assert_response :success
    assert_select "form#social-authorization-form[action='/social/apple'][method='post']", count: 1

    cycle = ClientSignUpFlow.order(:created_at).last

    assert_equal "apple", cycle.entry_method
    assert_equal "apple", cycle.social_provider
    assert_equal "social_callback", cycle.step
    assert_equal cycle.public_id, session[:auth_app_up_sequence_id]
  end

  test "continue renders a CSRF-protected POST form for Apple authorization" do
    get new_auth_app_social_apple_session_path(provider: "apple", ri: "jp")

    assert_response :success
    assert_select "form#social-authorization-form[action='/social/apple'][method='post'][data-turbo='false']", count: 1
    assert_select "form#social-authorization-form input[name='authenticity_token']", count: 1
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

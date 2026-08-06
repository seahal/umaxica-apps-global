# typed: false
# frozen_string_literal: true

require "test_helper"

# What the POST entry writes before handing the request to the OmniAuth request
# phase. The handoff itself and the absence of a GET entry are covered by
# test/integration/social_ceremony_entry_contract_test.rb.
class Auth::App::Social::CeremonyEntryTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
  end

  test "sign-in entry stores only the social ceremony transaction id in the cookie session" do
    post auth_app_social_google_session_path(provider: "google", ri: "jp")

    assert_response :temporary_redirect

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

  %w(google apple).each do |provider|
    test "#{provider} sign-up entry issues a sign-up flow" do
      assert_difference("ClientSignUpFlow.count", 1) do
        post public_send(:"auth_app_social_#{provider}_registration_path", provider: provider, ri: "jp")
      end

      assert_response :temporary_redirect

      cycle = ClientSignUpFlow.order(:created_at).last

      assert_equal provider, cycle.entry_method
      assert_equal provider, cycle.social_provider
      assert_equal "social_callback", cycle.step
      assert_equal cycle.public_id, session[:auth_app_up_sequence_id]
    end
  end

  # The provider comes from a route default, so an unsupported one is not
  # reachable through routing. Only the two supported providers have routes.
  test "no route exists for a provider outside the supported set" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/social/microsoft/session", method: :post)
    end
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class OauthCallbackStateTest < ActiveSupport::TestCase
  test "client oauth callback state is consumed once" do
    ClientOauthCallbackState.issue!(state: "state-one", provider: "google_app", intent: "login")

    assert ClientOauthCallbackState.consume!(state: "state-one", provider: "google_app")
    assert_not ClientOauthCallbackState.consume!(state: "state-one", provider: "google_app")
  end

  test "oauth callback state issue rejects blank input and operator state consumes" do
    assert_nil ClientOauthCallbackState.issue!(state: nil, provider: "google_app", intent: "login")
    assert_nil ClientOauthCallbackState.issue!(state: "state-one", provider: nil, intent: "login")
    assert_not ClientOauthCallbackState.consume!(state: nil, provider: "google_app")
    assert_not ClientOauthCallbackState.consume!(state: "state-one", provider: nil)

    OperatorOauthCallbackState.issue!(state: "state-two", provider: "google_app", intent: "login")

    assert OperatorOauthCallbackState.consume!(state: "state-two", provider: "google_app")
  end

  test "callback state store ignores unsupported org and com google providers" do
    assert_not SocialAuthCallbackStateStore.issue!(state: "state-two", provider: "google_#{"org"}", intent: "login")
    assert_not SocialAuthCallbackStateStore.consume!(state: "state-two", provider: "google_#{"org"}")

    assert_not SocialAuthCallbackStateStore.issue!(state: "state-three", provider: "google_#{"com"}", intent: "login")
    assert_not SocialAuthCallbackStateStore.consume!(state: "state-three", provider: "google_#{"com"}")
  end

  test "issue recovers from a race-condition uniqueness violation" do
    ClientOauthCallbackState.issue!(state: "race-state", provider: "google_app", intent: "login")
    existing = ClientOauthCallbackState.find_by!(state_digest: ClientOauthCallbackState.digest_state("race-state"))

    ClientOauthCallbackState.stub(:find_or_create_by!, ->(*) { raise ActiveRecord::RecordNotUnique, "duplicate" }) do
      result = ClientOauthCallbackState.issue!(state: "race-state", provider: "google_app", intent: "login")

      assert_equal existing, result
    end
  end
end

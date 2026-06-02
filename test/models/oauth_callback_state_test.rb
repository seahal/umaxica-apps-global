# typed: false
# frozen_string_literal: true

require "test_helper"

class OauthCallbackStateTest < ActiveSupport::TestCase
  test "client oauth callback state is consumed once" do
    ClientOauthCallbackState.issue!(state: "state-one", provider: "google_app", intent: "login")

    assert ClientOauthCallbackState.consume!(state: "state-one", provider: "google_app")
    assert_not ClientOauthCallbackState.consume!(state: "state-one", provider: "google_app")
  end

  test "callback state store ignores unsupported org and com google providers" do
    assert_not SocialAuth::CallbackStateStore.issue!(state: "state-two", provider: "google_#{"org"}", intent: "login")
    assert_not SocialAuth::CallbackStateStore.consume!(state: "state-two", provider: "google_#{"org"}")

    assert_not SocialAuth::CallbackStateStore.issue!(state: "state-three", provider: "google_#{"com"}", intent: "login")
    assert_not SocialAuth::CallbackStateStore.consume!(state: "state-three", provider: "google_#{"com"}")
  end
end

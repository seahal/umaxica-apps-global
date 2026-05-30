# typed: false
# frozen_string_literal: true

require "test_helper"

class OauthCallbackStateTest < ActiveSupport::TestCase
  test "client oauth callback state is consumed once" do
    ClientOauthCallbackState.issue!(state: "state-one", provider: "google_app", intent: "login")

    assert ClientOauthCallbackState.consume!(state: "state-one", provider: "google_app")
    assert_not ClientOauthCallbackState.consume!(state: "state-one", provider: "google_app")
  end

  test "operator oauth callback state is provider scoped" do
    OperatorOauthCallbackState.issue!(state: "state-two", provider: "google_org", intent: "login")

    assert_not OperatorOauthCallbackState.consume!(state: "state-two", provider: "google_app")
    assert OperatorOauthCallbackState.consume!(state: "state-two", provider: "google_org")
  end
end

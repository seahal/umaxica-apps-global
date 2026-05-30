# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialCallbackStateTest < ActiveSupport::TestCase
  test "client social callback state is consumed once" do
    ClientSocialCallbackState.issue!(state: "state-one", provider: "google_app", intent: "login")

    assert ClientSocialCallbackState.consume!(state: "state-one", provider: "google_app")
    assert_not ClientSocialCallbackState.consume!(state: "state-one", provider: "google_app")
  end

  test "operator social callback state is provider scoped" do
    OperatorSocialCallbackState.issue!(state: "state-two", provider: "google_org", intent: "login")

    assert_not OperatorSocialCallbackState.consume!(state: "state-two", provider: "google_app")
    assert OperatorSocialCallbackState.consume!(state: "state-two", provider: "google_org")
  end
end

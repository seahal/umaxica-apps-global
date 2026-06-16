# typed: false
# frozen_string_literal: true

require "test_helper"

class Actor::AuthenticationTest < ActiveSupport::TestCase
  fixtures_none!

  test "exposes minimal signed-in authentication facts" do
    auth = Actor::Authentication.new(
      login_public_id: "login-123",
      acr: "aal1",
      amr: ["passcode"],
      actor_type: :client,
      actor_id: 42,
      restricted: true,
      active_sign_sequence_id: "sequence-123",
    )

    assert_predicate auth, :signed_in?
    assert_equal :aal1, auth.aal
    assert_predicate auth, :aal1?
    assert_predicate auth, :restricted?
    assert_equal :client, auth.actor_type
    assert_equal 42, auth.actor_id
    assert_equal "sequence-123", auth.active_sign_sequence_id
  end

  test "null authentication is not signed in" do
    assert_not Actor::Authentication::NULL.signed_in?
    assert_not Actor::Authentication::NULL.restricted?
  end

  test "hash is consistent for equal authentications" do
    auth1 = Actor::Authentication.new(
      login_public_id: "login-123",
      acr: "aal1",
      amr: ["passcode"],
      actor_type: :client,
      actor_id: 42,
      restricted: true,
      active_sign_sequence_id: "sequence-123",
    )
    auth2 = Actor::Authentication.new(
      login_public_id: "login-123",
      acr: "aal1",
      amr: ["passcode"],
      actor_type: :client,
      actor_id: 42,
      restricted: true,
      active_sign_sequence_id: "sequence-123",
    )

    assert_equal auth1.hash, auth2.hash
    assert_equal Set[auth1, auth2].size, 1
  end

  test "hash differs for different authentications" do
    auth1 = Actor::Authentication.new(login_public_id: "login-123")
    auth2 = Actor::Authentication::NULL

    assert_not_equal auth1.hash, auth2.hash
  end
end

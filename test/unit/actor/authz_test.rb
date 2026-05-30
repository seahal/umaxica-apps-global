# typed: false
# frozen_string_literal: true

require "test_helper"

class ActorAuthzTest < ActiveSupport::TestCase
  test "NULL constant is a frozen null instance" do
    null_instance = Actor::Authz::NULL

    assert_predicate null_instance, :frozen?
    assert_predicate null_instance, :null?
    assert_nil null_instance.policy_user
    assert_nil null_instance.token_claims
    assert_nil null_instance.surface
  end

  test "null class method returns the NULL constant" do
    null_instance = Actor::Authz::NULL

    assert_predicate null_instance, :null?
    assert_predicate null_instance, :frozen?
  end

  test "null? returns true when all fields are blank" do
    authz = Actor::Authz.new(policy_user: nil, token_claims: nil, surface: nil)

    assert_predicate authz, :null?
  end

  test "null? returns true when all fields are empty strings" do
    authz = Actor::Authz.new(policy_user: "", token_claims: "", surface: "")

    assert_predicate authz, :null?
  end

  test "null? returns false when policy_user is present" do
    authz = Actor::Authz.new(policy_user: "user_1", token_claims: nil, surface: nil)

    assert_not authz.null?
  end

  test "null? returns false when token_claims is present" do
    authz = Actor::Authz.new(policy_user: nil, token_claims: { "scp" => ["read"] }, surface: nil)

    assert_not authz.null?
  end

  test "null? returns false when surface is present" do
    authz = Actor::Authz.new(policy_user: nil, token_claims: nil, surface: "app")

    assert_not authz.null?
  end

  test "null? returns false when multiple fields are present" do
    authz = Actor::Authz.new(policy_user: "user_1", token_claims: {}, surface: "org")

    assert_not authz.null?
  end

  test "initialized with all fields returns correct values" do
    authz = Actor::Authz.new(policy_user: "admin", token_claims: { "sub" => 42 }, surface: "app")

    assert_equal "admin", authz.policy_user
    assert_equal({ "sub" => 42 }, authz.token_claims)
    assert_equal "app", authz.surface
  end
end

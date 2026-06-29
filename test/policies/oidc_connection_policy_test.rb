# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

# Object-level authorization for the per-surface OIDC connection listings.
# Each policy's index?/show? allows only the owning actor type; everyone else is denied.
# Row-level ownership (current_actor.oidc_connections) stays enforced by the controllers.
class OidcConnectionPolicyTest < ActiveSupport::TestCase
  fixtures :clients, :operators

  def visitor
    @visitor ||= create_verified_visitor_with_email(
      email_address: "oidc-policy-#{SecureRandom.hex(4)}@example.com",
    )
  end

  # --- ClientOidcConnectionPolicy (app surface) ---

  test "client may list its OIDC connections" do
    policy = ClientOidcConnectionPolicy.new(ClientOidcConnection, user: clients(:one))

    assert policy.apply(:index?)
    assert policy.apply(:show?)
  end

  test "non-client may not list app OIDC connections" do
    [operators(:one), visitor, nil].each do |actor|
      policy = ClientOidcConnectionPolicy.new(ClientOidcConnection, user: actor)

      assert_not policy.apply(:index?), "expected #{actor.class} to be denied"
      assert_not policy.apply(:show?), "expected #{actor.class} to be denied"
    end
  end

  # --- VisitorOidcConnectionPolicy (com surface) ---

  test "visitor may list its OIDC connections" do
    policy = VisitorOidcConnectionPolicy.new(VisitorOidcConnection, user: visitor)

    assert policy.apply(:index?)
    assert policy.apply(:show?)
  end

  test "non-visitor may not list com OIDC connections" do
    [clients(:one), operators(:one), nil].each do |actor|
      policy = VisitorOidcConnectionPolicy.new(VisitorOidcConnection, user: actor)

      assert_not policy.apply(:index?), "expected #{actor.class} to be denied"
      assert_not policy.apply(:show?), "expected #{actor.class} to be denied"
    end
  end

  # --- OperatorOidcConnectionPolicy (org surface) ---

  test "operator may list its OIDC connections" do
    policy = OperatorOidcConnectionPolicy.new(OperatorOidcConnection, user: operators(:one))

    assert policy.apply(:index?)
    assert policy.apply(:show?)
  end

  test "non-operator may not list org OIDC connections" do
    [clients(:one), visitor, nil].each do |actor|
      policy = OperatorOidcConnectionPolicy.new(OperatorOidcConnection, user: actor)

      assert_not policy.apply(:index?), "expected #{actor.class} to be denied"
      assert_not policy.apply(:show?), "expected #{actor.class} to be denied"
    end
  end

  # --- destroy? (unlinking): owner-only per record ---

  test "client may destroy its own OIDC connection but not another client's" do
    owner = clients(:one)
    own = ClientOidcConnection.new(user_id: owner.id)
    other = ClientOidcConnection.new(user_id: owner.id + 1)

    assert_predicate ClientOidcConnectionPolicy.new(own, user: owner), :destroy?
    assert_not ClientOidcConnectionPolicy.new(other, user: owner).destroy?
    assert_not ClientOidcConnectionPolicy.new(own, user: nil).destroy?
  end

  test "visitor may destroy its own OIDC connection but not another visitor's" do
    owner = visitor
    own = VisitorOidcConnection.new(visitor_id: owner.id)
    other = VisitorOidcConnection.new(visitor_id: owner.id + 1)

    assert_predicate VisitorOidcConnectionPolicy.new(own, user: owner), :destroy?
    assert_not VisitorOidcConnectionPolicy.new(other, user: owner).destroy?
    assert_not VisitorOidcConnectionPolicy.new(own, user: nil).destroy?
  end

  test "operator may destroy its own OIDC connection but not another operator's" do
    owner = operators(:one)
    own = OperatorOidcConnection.new(staff_id: owner.id)
    other = OperatorOidcConnection.new(staff_id: owner.id + 1)

    assert_predicate OperatorOidcConnectionPolicy.new(own, user: owner), :destroy?
    assert_not OperatorOidcConnectionPolicy.new(other, user: owner).destroy?
    assert_not OperatorOidcConnectionPolicy.new(own, user: nil).destroy?
  end
end

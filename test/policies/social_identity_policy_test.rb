# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialIdentityPolicyTest < ActiveSupport::TestCase
  fixtures :clients, :operators

  test "client google identity destroy allows owner only" do
    owner = clients(:one)
    other = clients(:two)
    identity = ClientGoogleIdentity.new(user_id: owner.id)

    assert_predicate ClientGoogleIdentityPolicy.new(identity, user: owner), :destroy?
    assert_not ClientGoogleIdentityPolicy.new(identity, user: other).destroy?
    assert_not ClientGoogleIdentityPolicy.new(identity, user: operators(:one)).destroy?
  end

  test "client apple identity destroy allows owner only" do
    owner = clients(:one)
    other = clients(:two)
    identity = ClientAppleIdentity.new(user_id: owner.id)

    assert_predicate ClientAppleIdentityPolicy.new(identity, user: owner), :destroy?
    assert_not ClientAppleIdentityPolicy.new(identity, user: other).destroy?
    assert_not ClientAppleIdentityPolicy.new(identity, user: operators(:one)).destroy?
  end
end

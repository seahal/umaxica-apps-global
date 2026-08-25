# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SocialIdentityPolicyTest < ActiveSupport::TestCase
  fixtures :clients, :operators

  test "client google identity destroy allows owner only" do
    owner = clients(:one)
    other = clients(:two)
    identity = ClientExternalIdentity.new(client: owner, provider: "google")

    assert_predicate ClientExternalIdentityPolicy.new(identity, user: owner), :destroy?
    assert_not ClientExternalIdentityPolicy.new(identity, user: other).destroy?
    assert_not ClientExternalIdentityPolicy.new(identity, user: operators(:one)).destroy?
  end

  test "client apple identity destroy allows owner only" do
    owner = clients(:one)
    other = clients(:two)
    identity = ClientExternalIdentity.new(client: owner, provider: "apple")

    assert_predicate ClientExternalIdentityPolicy.new(identity, user: owner), :destroy?
    assert_not ClientExternalIdentityPolicy.new(identity, user: other).destroy?
    assert_not ClientExternalIdentityPolicy.new(identity, user: operators(:one)).destroy?
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientExternalIdentityPolicyTest < ActiveSupport::TestCase
  test "allows only the owning client to unlink an external identity" do
    owner = Client.new(id: 1)
    other = Client.new(id: 2)
    identity = ClientExternalIdentity.new(client: owner)

    assert_predicate ClientExternalIdentityPolicy.new(identity, user: owner), :destroy?
    assert_not_predicate ClientExternalIdentityPolicy.new(identity, user: other), :destroy?
  end
end

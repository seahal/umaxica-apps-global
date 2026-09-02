# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationLoginResultTest < ActiveSupport::TestCase
  test "authenticated result requires user identity and an existing account" do
    user = Object.new
    identity = Object.new
    result = ExternalAuthentication::LoginResult.new(
      status: :authenticated, user: user, identity: identity, existing_account: true,
    )

    assert_predicate result, :authenticated?
    assert_raises(ArgumentError) do
      ExternalAuthentication::LoginResult.new(
        status: :authenticated, user: nil, identity: identity, existing_account: true,
      )
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::LoginResult.new(
        status: :authenticated, user: user, identity: identity, existing_account: false,
      )
    end
  end

  test "rejects an unsupported status" do
    assert_raises(ArgumentError) do
      ExternalAuthentication::LoginResult.new(
        status: :link_completed, user: nil, identity: nil, existing_account: false,
      )
    end
  end
end

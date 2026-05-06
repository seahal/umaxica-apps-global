# typed: false
# frozen_string_literal: true

require "test_helper"

class Oidc::SingleLogoutServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "revokes all active user tokens" do
    # Create some active tokens
    token1 = UserToken.create!(
      user: @user,
      public_id: SecureRandom.alphanumeric(21),
      refresh_expires_at: 30.days.from_now,
      status: "active",
    )
    token2 = UserToken.create!(
      user: @user,
      public_id: SecureRandom.alphanumeric(21),
      refresh_expires_at: 30.days.from_now,
      status: "active",
    )

    Oidc::SingleLogoutService.call(user: @user)

    token1.reload
    token2.reload

    assert_predicate token1.revoked_at, :present?
    assert_equal "revoked", token1.status
    assert_predicate token2.revoked_at, :present?
    assert_equal "revoked", token2.status
  end

  test "uses mark connection for user logout" do
    connection_calls = []

    MarkRecord.stub(:connected_to, ->(**options, &block) { connection_calls << options; block.call }) do
      Oidc::SingleLogoutService.call(user: @user)
    end

    assert connection_calls.any? { |options| options[:role] == :writing }
  end

  test "does not affect already revoked tokens" do
    revoked_at = 1.hour.ago
    token = UserToken.create!(
      user: @user,
      public_id: SecureRandom.alphanumeric(21),
      refresh_expires_at: 30.days.from_now,
      status: "revoked",
      revoked_at: revoked_at,
    )

    Oidc::SingleLogoutService.call(user: @user)

    token.reload
    # revoked_at should not change since it was already set
    assert_in_delta Float(revoked_at), Float(token.revoked_at), 1.0
  end

  test "does not affect other users tokens" do
    other_user = users(:two)
    other_token = UserToken.create!(
      user: other_user,
      public_id: SecureRandom.alphanumeric(21),
      refresh_expires_at: 30.days.from_now,
      status: "active",
    )

    Oidc::SingleLogoutService.call(user: @user)

    other_token.reload

    assert_nil other_token.revoked_at
    assert_equal "active", other_token.status
  end
end

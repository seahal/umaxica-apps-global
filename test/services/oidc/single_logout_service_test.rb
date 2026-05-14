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
      lapses_at: 30.days.from_now,
      user_token_status_id: UserTokenStatus::ACTIVE,
    )
    token2 = UserToken.create!(
      user: @user,
      public_id: SecureRandom.alphanumeric(21),
      lapses_at: 30.days.from_now,
      user_token_status_id: UserTokenStatus::ACTIVE,
    )

    Oidc::SingleLogoutService.call(user: @user)

    token1.reload
    token2.reload

    assert_predicate token1.lapses_at, :present?
    assert_equal UserTokenStatus::REVOKED, token1.user_token_status_id
    assert_predicate token2.lapses_at, :present?
    assert_equal UserTokenStatus::REVOKED, token2.user_token_status_id
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
      user_token_status_id: UserTokenStatus::REVOKED,
      lapses_at: revoked_at,
    )

    Oidc::SingleLogoutService.call(user: @user)

    token.reload
    # revoked_at should not change since it was already set
    assert_in_delta Float(revoked_at), Float(token.lapses_at), 1.0
  end

  test "does not affect other users tokens" do
    other_user = users(:two)
    other_token = UserToken.create!(
      user: other_user,
      public_id: SecureRandom.alphanumeric(21),
      lapses_at: 30.days.from_now,
      user_token_status_id: UserTokenStatus::ACTIVE,
    )

    Oidc::SingleLogoutService.call(user: @user)

    other_token.reload

    assert_predicate other_token, :currently_usable?
    assert_equal UserTokenStatus::ACTIVE, other_token.user_token_status_id
  end

  test "revokes all active visitor tokens" do
    visitor = create_verified_visitor_with_email(email_address: "slo-visitor-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(
      visitor: visitor,
      public_id: SecureRandom.alphanumeric(21),
      lapses_at: 30.days.from_now,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
    )

    Oidc::SingleLogoutService.call_for_visitor(visitor: visitor)

    assert_equal VisitorTokenStatus::REVOKED, token.reload.visitor_token_status_id
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class TokenStatusManagementTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      public_id: "u_#{SecureRandom.hex(8)}",
      status_id: UserStatus::NOTHING,
      created_at: 1.day.ago,
      updated_at: 1.day.ago,
    )
    @token = UserToken.create!(
      user: @user,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      lapses_at: 1.day.from_now,
      purge_at: 2.days.from_now,
      created_at: 1.day.ago,
      updated_at: 1.day.ago,
    )
  end

  test "defines status constants" do
    assert_equal 1, TokenStatusManagement::STATUS_ACTIVE
    assert_equal 102, TokenStatusManagement::STATUS_EXPIRED
    assert_equal 103, TokenStatusManagement::STATUS_RESTRICTED
    assert_equal 104, TokenStatusManagement::STATUS_REVOKED
    assert_equal [1, 102, 103, 104], TokenStatusManagement::VALID_STATUSES
  end

  test "defines restricted ttl" do
    assert_equal 15.minutes, TokenStatusManagement::RESTRICTED_TTL
  end

  test "active_status scope returns only active usable tokens" do
    @token.update!(user_token_status_id: UserTokenStatus::ACTIVE, lapses_at: 1.day.from_now)
    restricted = UserToken.create!(
      user: @user, user_token_status_id: UserTokenStatus::RESTRICTED, lapses_at: 1.day.from_now,
      purge_at: 2.days.from_now,
    )
    revoked = UserToken.create!(user: @user, lapses_at: Time.current, purge_at: 1.day.from_now)
    refresh_expired = UserToken.create!(
      user: @user, user_token_status_id: UserTokenStatus::ACTIVE, lapses_at: 1.minute.ago,
      purge_at: 1.day.from_now,
    )
    rotated_source = UserToken.create!(
      user: @user, user_token_status_id: UserTokenStatus::ACTIVE, lapses_at: 1.day.from_now,
      purge_at: 2.days.from_now,
    )
    rotated_refresh = rotated_source.rotate_refresh_token!
    Sign::RefreshTokenService.call(refresh_token: rotated_refresh)

    results = UserToken.active_status

    assert_includes results, @token
    assert_not_includes results, restricted
    assert_not_includes results, revoked
    assert_not_includes results, refresh_expired
    assert_not_includes results, rotated_source.reload
  end

  test "restricted_status scope returns only restricted usable tokens" do
    active = UserToken.create!(
      user: @user, user_token_status_id: UserTokenStatus::ACTIVE,
      lapses_at: 1.day.from_now, purge_at: 2.days.from_now,
    )
    @token.update!(user_token_status_id: UserTokenStatus::RESTRICTED, lapses_at: 1.day.from_now)
    revoked = UserToken.create!(
      user: @user, user_token_status_id: UserTokenStatus::RESTRICTED,
      lapses_at: Time.current, purge_at: 1.day.from_now,
    )
    refresh_expired = UserToken.create!(
      user: @user, user_token_status_id: UserTokenStatus::RESTRICTED, lapses_at: 1.minute.ago,
      purge_at: 1.day.from_now,
    )

    results = UserToken.restricted_status

    assert_includes results, @token
    assert_not_includes results, active
    assert_not_includes results, revoked
    assert_not_includes results, refresh_expired
  end

  test "not_revoked scope returns only usable tokens" do
    @token.update!(lapses_at: 1.day.from_now)
    revoked = UserToken.create!(user: @user, lapses_at: Time.current, purge_at: 1.day.from_now)
    refresh_expired = UserToken.create!(user: @user, lapses_at: 1.minute.ago, purge_at: 1.day.from_now)
    rotated_source = UserToken.create!(user: @user, lapses_at: 1.day.from_now, purge_at: 2.days.from_now)
    rotated_refresh = rotated_source.rotate_refresh_token!
    Sign::RefreshTokenService.call(refresh_token: rotated_refresh)

    results = UserToken.not_revoked

    assert_includes results, @token
    assert_not_includes results, revoked
    assert_not_includes results, refresh_expired
    assert_not_includes results, rotated_source.reload
  end

  test "future lapses_at stays valid until due and past lapses_at is excluded" do
    future_token = UserToken.create!(user: @user, lapses_at: 10.minutes.from_now, purge_at: 1.day.from_now)
    past_token = UserToken.create!(user: @user, lapses_at: 10.minutes.ago, purge_at: 1.day.from_now)

    results = UserToken.not_revoked

    assert_includes results, future_token
    assert_not_includes results, past_token
    assert_not future_token.expired?
    assert_predicate past_token, :expired?
  end

  test "restricted? returns true when status is restricted" do
    @token.update!(user_token_status_id: UserTokenStatus::RESTRICTED)

    assert_predicate @token, :restricted?

    @token.update!(user_token_status_id: UserTokenStatus::ACTIVE)

    assert_not_predicate @token, :restricted?
  end

  test "active_status? returns true only when active and currently usable" do
    @token.update!(user_token_status_id: UserTokenStatus::ACTIVE, lapses_at: 1.day.from_now, purge_at: 1.day.from_now)

    assert_predicate @token, :active_status?

    @token.update!(user_token_status_id: UserTokenStatus::RESTRICTED)

    assert_not_predicate @token, :active_status?

    @token.update!(user_token_status_id: UserTokenStatus::ACTIVE, lapses_at: Time.current, purge_at: 1.day.from_now)

    assert_not_predicate @token, :active_status?
  end

  test "revoked? returns true when status is revoked" do
    @token.update!(user_token_status_id: UserTokenStatus::REVOKED)

    assert_predicate @token, :revoked?

    @token.update!(user_token_status_id: UserTokenStatus::ACTIVE)

    assert_not_predicate @token, :revoked?
  end

  test "expired? handles blank and infinite lapses_at" do
    token = UserToken.new(user: @user, user_token_kind_id: UserTokenKind::BROWSER_WEB)

    token.define_singleton_method(:lapses_at) { nil }

    assert_not token.send(:expired?)

    token.define_singleton_method(:lapses_at) { Float::INFINITY }

    assert_not token.send(:expired?)
  end

  test "scheduled_revocation_due? tracks past lapses_at" do
    token = UserToken.new(user: @user, user_token_kind_id: UserTokenKind::BROWSER_WEB)
    token.define_singleton_method(:lapses_at) { 1.minute.ago }

    assert_predicate token, :scheduled_revocation_due?
    assert_predicate token, :expired?
  end

  test "currently_usable? returns false for rotated and expired tokens" do
    @token.update!(user_token_status_id: UserTokenStatus::ACTIVE, lapses_at: 1.day.from_now, purge_at: 1.day.from_now)

    assert_predicate @token, :currently_usable?

    @token.update!(rotated_at: Time.current)

    assert_not_predicate @token, :currently_usable?

    @token.update!(rotated_at: nil, lapses_at: 1.minute.from_now)

    assert_predicate @token, :currently_usable?

    travel 2.minutes do
      assert_not_predicate @token.reload, :currently_usable?
    end
  end

  test "mark_restricted! updates status to restricted" do
    @token.update!(user_token_status_id: UserTokenStatus::ACTIVE)
    @token.mark_restricted!

    assert_equal UserTokenStatus::RESTRICTED, @token.reload.user_token_status_id
  end

  test "promote_to_active! updates status to active" do
    @token.update!(user_token_status_id: UserTokenStatus::RESTRICTED)
    @token.promote_to_active!

    assert_equal UserTokenStatus::ACTIVE, @token.reload.user_token_status_id
  end

  test "expiry_column returns lapses_at when present" do
    assert_equal :lapses_at, UserToken.expiry_column
  end

  test "revoke! sets expired_at and status to revoked" do
    freeze_time do
      @token.revoke!

      assert_predicate @token.lapses_at, :present?
      assert_in_delta Time.current.to_f, @token.lapses_at.to_f, 1
      assert_equal UserTokenStatus::REVOKED, @token.user_token_status_id
    end
  end

  test "revoke! restores missing revoked status reference" do
    UserTokenStatus.find(UserTokenStatus::REVOKED).destroy!

    @token.revoke!

    assert UserTokenStatus.exists?(id: UserTokenStatus::REVOKED)
    assert_equal UserTokenStatus::REVOKED, @token.reload.user_token_status_id
  end

  test "default token status is active" do
    token = UserToken.new(user: @user)

    assert_equal UserTokenStatus::ACTIVE, token.user_token_status_id
  end

  test "expiry_column raises when model has no expiry columns" do
    klass =
      Class.new do
        extend TokenStatusManagement::ClassMethods

        define_singleton_method(:column_names) do
          []
        end

        define_singleton_method(:name) do
          "NoExpiryToken"
        end
      end

    assert_raises(ArgumentError) { klass.expiry_column }
  end

  test "works with OperatorToken as well" do
    staff = Operator.find_by!(public_id: "BCDE2345FGHJ67KM")
    token = OperatorToken.create!(staff: staff)

    assert_predicate token, :active_status?

    token.mark_restricted!

    assert_predicate token, :restricted?

    token.promote_to_active!

    assert_predicate token, :active_status?

    token.revoke!

    assert_equal OperatorTokenStatus::REVOKED, token.reload.staff_token_status_id
  end
end

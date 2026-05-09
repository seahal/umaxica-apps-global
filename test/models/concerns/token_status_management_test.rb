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
    assert_equal "active", TokenStatusManagement::STATUS_ACTIVE
    assert_equal "restricted", TokenStatusManagement::STATUS_RESTRICTED
    assert_equal "revoked", TokenStatusManagement::STATUS_REVOKED
    assert_equal %w(active restricted revoked), TokenStatusManagement::VALID_STATUSES
  end

  test "defines restricted ttl" do
    assert_equal 15.minutes, TokenStatusManagement::RESTRICTED_TTL
  end

  test "active_status scope returns only active usable tokens" do
    @token.update!(status: "active", lapses_at: 1.day.from_now)
    restricted = UserToken.create!(
      user: @user, status: "restricted", lapses_at: 1.day.from_now,
      purge_at: 2.days.from_now,
    )
    revoked = UserToken.create!(user: @user, lapses_at: Time.current, purge_at: 1.day.from_now)
    refresh_expired = UserToken.create!(
      user: @user, status: "active", lapses_at: 1.minute.ago,
      purge_at: 1.day.from_now,
    )
    rotated_source = UserToken.create!(
      user: @user, status: "active", lapses_at: 1.day.from_now,
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
    active = UserToken.create!(user: @user, status: "active", lapses_at: 1.day.from_now, purge_at: 2.days.from_now)
    @token.update!(status: "restricted", lapses_at: 1.day.from_now)
    revoked = UserToken.create!(user: @user, status: "restricted", lapses_at: Time.current, purge_at: 1.day.from_now)
    refresh_expired = UserToken.create!(
      user: @user, status: "restricted", lapses_at: 1.minute.ago,
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
    @token.update!(status: "restricted")

    assert_predicate @token, :restricted?

    @token.update!(status: "active")

    assert_not_predicate @token, :restricted?
  end

  test "active_status? returns true only when active and currently usable" do
    @token.update!(status: "active", lapses_at: 1.day.from_now, purge_at: 1.day.from_now)

    assert_predicate @token, :active_status?

    @token.update!(status: "restricted")

    assert_not_predicate @token, :active_status?

    @token.update!(status: "active", lapses_at: Time.current, purge_at: 1.day.from_now)

    assert_not_predicate @token, :active_status?
  end

  test "currently_usable? returns false for rotated and expired tokens" do
    @token.update!(status: "active", lapses_at: 1.day.from_now, purge_at: 1.day.from_now)

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
    @token.update!(status: "active")
    @token.mark_restricted!

    assert_equal "restricted", @token.reload.status
  end

  test "promote_to_active! updates status to active" do
    @token.update!(status: "restricted")
    @token.promote_to_active!

    assert_equal "active", @token.reload.status
  end

  test "revoke! sets expired_at and status to revoked" do
    freeze_time do
      @token.revoke!

      assert_predicate @token.lapses_at, :present?
      assert_in_delta Time.current.to_f, @token.lapses_at.to_f, 1
      assert_equal "revoked", @token.status
    end
  end

  test "validates status inclusion" do
    token = UserToken.new(user: @user, status: "invalid_status")

    assert_not token.valid?
    assert_not_empty token.errors[:status]
  end

  test "validates status length" do
    token = UserToken.new(user: @user, status: "a" * 21)

    assert_not token.valid?
    assert_not_empty token.errors[:status]
  end

  test "default status is active" do
    token = UserToken.new(user: @user)

    assert_equal "active", token.status
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

  test "works with StaffToken as well" do
    staff = Staff.find_by!(public_id: "BCDE2345FGHJ67KM")
    token = StaffToken.create!(staff: staff)

    assert_predicate token, :active_status?

    token.mark_restricted!

    assert_predicate token, :restricted?

    token.promote_to_active!

    assert_predicate token, :active_status?

    token.revoke!

    assert_equal "revoked", token.reload.status
  end
end

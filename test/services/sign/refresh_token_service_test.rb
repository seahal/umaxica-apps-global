# typed: false
# frozen_string_literal: true

require "test_helper"

class SignRefreshTokenIssuerTest < ActiveSupport::TestCase
  test "invalid refresh token format returns failure reason" do
    result = SignRefreshTokenIssuer.call(refresh_token: "not-a-refresh-token")

    assert_not result.success?
    assert_equal :invalid_format, result.reason
  end

  test "unknown refresh token public id returns failure reason" do
    refresh = ClientToken.build_refresh_token("missing-public-id", "verifier")

    result = SignRefreshTokenIssuer.call(refresh_token: refresh)

    assert_not result.success?
    assert_equal :token_not_found, result.reason
  end

  test "rotation increments generation counter" do
    token = ClientToken.create!(
      user: create_verified_user_with_email(email_address: "refresh-rotate-#{SecureRandom.hex(4)}@example.com"),
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )
    first_refresh = token.rotate_refresh_token!
    result = SignRefreshTokenIssuer.call(refresh_token: first_refresh)

    new_token = result[:token]

    assert_not_equal token.id, new_token.id
    assert_equal token.refresh_token_generation + 1, new_token.refresh_token_generation
    assert_equal token.refresh_token_family_id, new_token.refresh_token_family_id
    assert_predicate token.reload.rotated_at, :present?
    assert_predicate result, :success?
    assert_equal new_token, result[:token]
  end

  test "rotation preserves device_session and advances current refresh token pointer" do
    token = ClientToken.create!(
      user: create_verified_user_with_email(email_address: "refresh-device-session-#{SecureRandom.hex(4)}@example.com"),
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )
    device_session = token.device_session
    refresh = token.rotate_refresh_token!

    result = SignRefreshTokenIssuer.call(refresh_token: refresh)
    new_token = result[:token]

    assert_predicate device_session, :present?
    assert_equal device_session.id, new_token.device_session_id
    assert_equal new_token.id, device_session.reload.current_refresh_token_id
    assert_equal new_token.refresh_token_family_id, device_session.refresh_token_family_id
  end

  test "rotation preserves DPoP JKT binding" do
    jkt = "dpop-jkt-#{SecureRandom.hex(8)}"
    token = ClientToken.create!(
      user: create_verified_user_with_email(email_address: "refresh-dpop-#{SecureRandom.hex(4)}@example.com"),
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
      dpop_jkt: jkt,
    )
    first_refresh = token.rotate_refresh_token!

    result = SignRefreshTokenIssuer.call(refresh_token: first_refresh)

    assert_equal jkt, result[:token].dpop_jkt
    assert_equal token.refresh_token_family_id, result[:token].refresh_token_family_id
  end

  test "reuse detection revokes all actor tokens" do
    user = create_verified_user_with_email(email_address: "refresh-reuse-#{SecureRandom.hex(4)}@example.com")
    token = ClientToken.create!(user: user, discarded_at: 1.day.from_now, purged_at: 2.days.from_now)
    initial_refresh = token.rotate_refresh_token!
    rotated = SignRefreshTokenIssuer.call(refresh_token: initial_refresh)
    rotated_refresh = rotated[:refresh_token]

    reuse_result = SignRefreshTokenIssuer.call(refresh_token: initial_refresh)

    assert_not reuse_result.success?
    assert_equal :refresh_token_reuse_detected, reuse_result.reason

    token.reload

    assert_operator token.discarded_at, :<=, Time.current, "Original token should be revoked"
    assert_operator ClientToken.where(user_id: user.id).maximum(:discarded_at), :<=, Time.current,
                    "All actor tokens should be revoked"

    rotated_result = SignRefreshTokenIssuer.call(refresh_token: rotated_refresh)

    assert_not rotated_result.success?
    assert_equal :inactive_token, rotated_result.reason
  end

  test "reuse detection revokes the token family while the request is readonly" do
    user = create_verified_user_with_email(email_address: "refresh-reuse-readonly-#{SecureRandom.hex(4)}@example.com")
    token = ClientToken.create!(user: user, discarded_at: 1.day.from_now, purged_at: 2.days.from_now)
    initial_refresh = token.rotate_refresh_token!

    rotated = SignRefreshTokenIssuer.call(refresh_token: initial_refresh)

    AppTicketRecord.connected_to(role: :reading, prevent_writes: true) do
      reuse_result = SignRefreshTokenIssuer.call(refresh_token: initial_refresh)

      assert_not reuse_result.success?
      assert_equal :refresh_token_reuse_detected, reuse_result.reason
    end

    assert_operator token.reload.discarded_at, :<=, Time.current
    assert_operator rotated.fetch(:token).reload.discarded_at, :<=, Time.current
  end

  test "revoked tokens stay invalid without marking compromise" do
    token = ClientToken.create!(
      user: create_verified_user_with_email(email_address: "refresh-revoked-#{SecureRandom.hex(4)}@example.com"),
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )
    refresh = token.rotate_refresh_token!
    token.revoke!

    result = SignRefreshTokenIssuer.call(refresh_token: refresh)

    assert_not result.success?
    assert_equal :inactive_token, result.reason

    assert_predicate token.reload.discarded_at, :present?
    assert_equal ClientTokenStatus::REVOKED, token.reload.user_token_status_id
  end

  test "invalid verifier for known public id does not revoke actor tokens" do
    user = create_verified_user_with_email(email_address: "refresh-invalid-digest-#{SecureRandom.hex(4)}@example.com")
    token = ClientToken.create!(user: user, discarded_at: 1.day.from_now, purged_at: 2.days.from_now)
    refresh = token.rotate_refresh_token!
    public_id, = ClientToken.parse_refresh_token(refresh)
    forged_refresh = ClientToken.build_refresh_token(public_id, "wrong-verifier")

    result = SignRefreshTokenIssuer.call(refresh_token: forged_refresh)

    assert_not result.success?
    assert_equal :invalid_digest, result.reason

    assert_operator token.reload.discarded_at, :>, Time.current
    assert_nil token.rotated_at
  end

  test "scheduled revoked tokens are invalid after discarded_at passes" do
    freeze_time do
      token = ClientToken.create!(
        user: create_verified_user_with_email(email_address: "refresh-scheduled-#{SecureRandom.hex(4)}@example.com"),
        discarded_at: 5.minutes.from_now,
        purged_at: 1.day.from_now,
      )
      refresh = token.rotate_refresh_token!
      travel 6.minutes

      result = SignRefreshTokenIssuer.call(refresh_token: refresh)

      assert_not result.success?
      assert_equal :inactive_token, result.reason
    end
  end

  test "S2: service uses writing role for lock and update operations" do
    # Verify that ActiveRecord::Base.connected_to is called with role: :writing
    # This ensures SELECT ... FOR UPDATE and UPDATE go to primary database
    original_method = ActiveRecord::Base.method(:connected_to)

    connection_calls = []
    ActiveRecord::Base.define_singleton_method(:connected_to) do |**options, &block|
      connection_calls << options
      original_method.call(**options, &block)
    end

    token = ClientToken.create!(
      user: create_verified_user_with_email(email_address: "refresh-writing-#{SecureRandom.hex(4)}@example.com"),
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )
    refresh = token.rotate_refresh_token!

    SignRefreshTokenIssuer.call(refresh_token: refresh)

    # Verify that connected_to was called with role: :writing
    assert connection_calls.any? { |opts| opts[:role] == :writing },
           "RefreshTokenService should use writing role for lock/update operations"
  ensure
    # Restore original method
    ActiveRecord::Base.define_singleton_method(:connected_to, original_method)
  end

  test "S2: no ReadOnlyError occurs during refresh" do
    # This test verifies that refresh operations do not trigger ReadOnlyError
    # even when using SELECT ... FOR UPDATE
    token = ClientToken.create!(
      user: create_verified_user_with_email(email_address: "refresh-readonly-#{SecureRandom.hex(4)}@example.com"),
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )
    refresh = token.rotate_refresh_token!

    assert_nothing_raised do
      result = SignRefreshTokenIssuer.call(refresh_token: refresh)

      assert_predicate result, :success?
      assert_not_equal token.id, result[:token].id
    end
  end

  test "rotation supports visitor refresh tokens" do
    visitor = create_refresh_visitor
    token = VisitorToken.create!(
      visitor: visitor,
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
    )
    refresh = token.rotate_refresh_token!

    result = SignRefreshTokenIssuer.call(refresh_token: refresh)

    assert_instance_of VisitorToken, result[:token]
    assert_not_equal token.id, result[:token].id
    assert_equal token.refresh_token_generation + 1, result[:token].refresh_token_generation
    assert_equal token.refresh_token_family_id, result[:token].refresh_token_family_id
    assert_predicate token.reload.rotated_at, :present?
  end

  test "visitor refresh reuse revokes all visitor tokens" do
    visitor = create_refresh_visitor
    token = VisitorToken.create!(visitor: visitor, discarded_at: 1.day.from_now, purged_at: 2.days.from_now)
    first_refresh = token.rotate_refresh_token!
    rotated = SignRefreshTokenIssuer.call(refresh_token: first_refresh)

    reuse_result = SignRefreshTokenIssuer.call(refresh_token: first_refresh)

    assert_not reuse_result.success?
    assert_equal :refresh_token_reuse_detected, reuse_result.reason

    assert_operator VisitorToken.where(visitor_id: visitor.id).maximum(:discarded_at), :<=, Time.current
    rotated_result = SignRefreshTokenIssuer.call(refresh_token: rotated[:refresh_token])

    assert_not rotated_result.success?
    assert_equal :inactive_token, rotated_result.reason
  end

  private

  def create_refresh_visitor
    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    VisitorTokenStatus.ensure_defaults!

    Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class RefreshTokenSharedTest < ActiveSupport::TestCase
  class DummyToken
    include RefreshTokenShared
  end

  test "generate_refresh_token builds public_id.verifier token" do
    token, verifier = DummyToken.generate_refresh_token(public_id: "pub")

    assert_match(/\Apub\./, token)
    assert_predicate verifier, :present?
    assert_equal token, DummyToken.build_refresh_token("pub", verifier)
  end

  test "parse_refresh_token returns public_id and verifier" do
    parsed = DummyToken.parse_refresh_token("abc.def")

    assert_equal ["abc", "def"], parsed
  end

  test "parse_refresh_token returns nil for invalid tokens" do
    assert_nil DummyToken.parse_refresh_token("")
    assert_nil DummyToken.parse_refresh_token("missing_separator")
    assert_nil DummyToken.parse_refresh_token("public_only.")
  end

  test "digest helpers handle legacy and verifier values" do
    digest = DummyToken.digest_refresh_token("verifier")
    legacy = DummyToken.legacy_refresh_token_digest("legacy")

    assert_predicate digest, :present?
    assert_predicate legacy, :present?
    assert_not_equal digest, legacy
  end

  test "secure_compare handles blanks safely" do
    assert_not DummyToken.secure_compare?(nil, "x")
    assert_not DummyToken.secure_compare?("x", nil)
    assert DummyToken.secure_compare?("same", "same")
  end

  test "lock_refresh_token_record_by_digest locks only unconsumed unexpired rows" do
    eligible_digest = AppPreference.digest_refresh_token("eligible-refresh")
    used_digest = AppPreference.digest_refresh_token("used-refresh")
    expired_digest = AppPreference.digest_refresh_token("expired-refresh")
    eligible = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discarded_at: 1.hour.from_now,
      token_digest: eligible_digest,
      jti: SecureRandom.uuid,
    )
    AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discarded_at: 1.hour.from_now,
      token_digest: used_digest,
      used_at: Time.current,
      jti: SecureRandom.uuid,
    )
    AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discarded_at: 1.minute.ago,
      token_digest: expired_digest,
      jti: SecureRandom.uuid,
    )

    record = AppPreference.lock_refresh_token_record_by_digest(
      eligible_digest,
      digest_column: :token_digest,
      unused_column: :used_at,
      expires_at_column: :discarded_at,
    )

    assert_equal eligible.id, record.id
    assert_nil AppPreference.lock_refresh_token_record_by_digest(
      used_digest,
      digest_column: :token_digest,
      unused_column: :used_at,
      expires_at_column: :discarded_at,
    )
    assert_nil AppPreference.lock_refresh_token_record_by_digest(
      expired_digest,
      digest_column: :token_digest,
      unused_column: :used_at,
      expires_at_column: :discarded_at,
    )
  end
end

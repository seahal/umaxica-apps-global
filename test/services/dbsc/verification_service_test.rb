# typed: false
# frozen_string_literal: true

require "test_helper"

class DbscVerificationServiceTest < ActiveSupport::TestCase
  test "verifies proof and returns ok for active user token without changing status" do
    user = create_verified_user_with_email(email_address: "dbsc-verify-#{SecureRandom.hex(4)}@example.com")
    token = ClientToken.create!(user: user, discarded_at: 1.day.from_now, purged_at: 2.days.from_now)
    private_key = OpenSSL::PKey::EC.generate("prime256v1")

    token.update!(
      user_token_binding_method_id: ClientTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: ClientTokenDbscStatus::ACTIVE,
      dbsc_session_id: "session-1",
      dbsc_public_key: { "kty" => "EC" },
      dbsc_challenge: "challenge-1",
      dbsc_challenge_issued_at: Time.current,
    )

    proof = JWT.encode(
      { "jti" => "challenge-1", "aud" => "https://test.host/verification", "iat" => Time.current.to_i },
      private_key, "ES256", { typ: "dbsc+jwt" },
    )

    DbscRecordAdapter.stub(:dbsc_public_key, private_key.public_key) do
      result = DbscVerificationService.call(
        record: token,
        session_id: "session-1",
        proof: proof,
      )

      assert result[:ok]
    end

    assert_equal ClientTokenDbscStatus::ACTIVE, token.reload.user_token_dbsc_status_id
  end

  test "validates active app preference proof with current challenge" do
    preference = AppPreference.create!(
      public_id: SecureRandom.hex(10),
      binding_method_id: AppPreferenceBindingMethod::DBSC,
      dbsc_status_id: AppPreferenceDbscStatus::ACTIVE,
      status_id: AppPreferenceStatus::NOTHING,
      discarded_at: 1.day.from_now,
      purged_at: 2.days.from_now,
      created_at: 1.day.ago,
      updated_at: 1.day.ago,
    )
    private_key = OpenSSL::PKey::EC.generate("prime256v1")

    preference.update!(
      binding_method_id: AppPreferenceBindingMethod::DBSC,
      dbsc_status_id: AppPreferenceDbscStatus::ACTIVE,
      dbsc_session_id: "pref-session-1",
      dbsc_public_key: { "kty" => "EC" },
    )

    preference.update!(dbsc_challenge: "challenge-2", dbsc_challenge_issued_at: Time.current)
    proof = JWT.encode(
      { "jti" => "challenge-2", "aud" => "https://test.host/verification", "iat" => Time.current.to_i },
      private_key, "ES256", { typ: "dbsc+jwt" },
    )

    DbscRecordAdapter.stub(:dbsc_public_key, private_key.public_key) do
      result = DbscVerificationService.call(
        record: preference,
        session_id: "pref-session-1",
        proof: proof,
      )

      assert result[:ok]
    end
  end

  test "rejects verification proof that carries a public key" do
    user = create_verified_user_with_email(email_address: "dbsc-verify-jwk-#{SecureRandom.hex(4)}@example.com")
    token = ClientToken.create!(user: user, discarded_at: 1.day.from_now, purged_at: 2.days.from_now)
    private_key = OpenSSL::PKey::EC.generate("prime256v1")

    token.update!(
      user_token_binding_method_id: ClientTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: ClientTokenDbscStatus::ACTIVE,
      dbsc_session_id: "session-jwk",
      dbsc_public_key: JWT::JWK.new(private_key).export,
      dbsc_challenge: "challenge-jwk",
      dbsc_challenge_issued_at: Time.current,
    )

    proof = JWT.encode(
      { "jti" => "challenge-jwk", "aud" => "https://test.host/verification", "iat" => Time.current.to_i },
      private_key, "ES256", { typ: "dbsc+jwt", jwk: JWT::JWK.new(private_key).export },
    )

    result = DbscVerificationService.call(
      record: token,
      session_id: "session-jwk",
      proof: proof,
    )

    assert_not result[:ok]
    assert_equal "unexpected_public_key", result[:error_code]
  end
end

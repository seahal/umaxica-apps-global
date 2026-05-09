# typed: false
# frozen_string_literal: true

require "test_helper"

class Dbsc::RegistrationServiceTest < ActiveSupport::TestCase
  test "sets user token to active dbsc state" do
    user = create_verified_user_with_email(email_address: "dbsc-registration-#{SecureRandom.hex(4)}@example.com")
    token = UserToken.create!(user: user, lapses_at: 1.day.from_now, purge_at: 2.days.from_now)
    token.update!(dbsc_challenge: "challenge-1", dbsc_challenge_issued_at: Time.current)
    private_key = OpenSSL::PKey::EC.generate("prime256v1")
    public_jwk = JWT::JWK.new(private_key).export

    proof = JWT.encode(
      { "jti" => "challenge-1", "aud" => "https://test.host/registration", "iat" => Time.current.to_i },
      private_key, "ES256", { typ: "dbsc+jwt", jwk: public_jwk },
    )

    result = Dbsc::RegistrationService.call(record: token, proof: proof, session_id: "dbsc-session-1")

    assert_predicate result[:ok], :present?

    token.reload

    assert_equal UserTokenBindingMethod::DBSC, token.user_token_binding_method_id
    assert_equal UserTokenDbscStatus::ACTIVE, token.user_token_dbsc_status_id
    assert_equal "dbsc-session-1", token.dbsc_session_id
    assert_equal public_jwk.stringify_keys, token.dbsc_public_key
    assert_nil token.dbsc_challenge
  end

  test "sets app preference to active dbsc state" do
    preference = AppPreference.create!(
      public_id: SecureRandom.hex(10),
      binding_method_id: AppPreferenceBindingMethod::NOTHING,
      dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
      status_id: AppPreferenceStatus::NOTHING,
      lapses_at: 1.day.from_now,
      purge_at: 2.days.from_now,
      created_at: 1.day.ago,
      updated_at: 1.day.ago,
    )
    preference.update!(dbsc_challenge: "challenge-2", dbsc_challenge_issued_at: Time.current)
    private_key = OpenSSL::PKey::EC.generate("prime256v1")
    public_jwk = JWT::JWK.new(private_key).export

    proof = JWT.encode(
      { "jti" => "challenge-2", "aud" => "https://test.host/registration", "iat" => Time.current.to_i },
      private_key, "ES256", { typ: "dbsc+jwt", jwk: public_jwk },
    )

    result = Dbsc::RegistrationService.call(record: preference, proof: proof, session_id: "dbsc-pref-1")

    assert_predicate result[:ok], :present?

    preference.reload

    assert_equal AppPreferenceBindingMethod::DBSC, preference.binding_method_id
    assert_equal AppPreferenceDbscStatus::ACTIVE, preference.dbsc_status_id
    assert_equal "dbsc-pref-1", preference.dbsc_session_id
    assert_equal public_jwk.stringify_keys, preference.dbsc_public_key
    assert_nil preference.dbsc_challenge
  end

  test "returns challenge_expired when dbsc_challenge_issued_at is too old" do
    user = create_verified_user_with_email(email_address: "dbsc-registration-old-#{SecureRandom.hex(4)}@example.com")
    token = UserToken.create!(user: user, lapses_at: 1.day.from_now, purge_at: 2.days.from_now)
    token.update!(dbsc_challenge: "old-challenge", dbsc_challenge_issued_at: 10.minutes.ago)
    private_key = OpenSSL::PKey::EC.generate("prime256v1")
    public_jwk = JWT::JWK.new(private_key).export

    proof = JWT.encode(
      { "jti" => "old-challenge", "aud" => "https://test.host/registration", "iat" => Time.current.to_i },
      private_key, "ES256", { typ: "dbsc+jwt", jwk: public_jwk },
    )

    result = Dbsc::RegistrationService.call(record: token, proof: proof, session_id: "dbsc-session-x")

    assert_not result[:ok]
    assert_equal "challenge_expired", result[:error_code]
  end

  test "returns challenge_expired when dbsc_challenge_issued_at is blank" do
    user = create_verified_user_with_email(email_address: "dbsc-registration-blank-#{SecureRandom.hex(4)}@example.com")
    token = UserToken.create!(user: user, lapses_at: 1.day.from_now, purge_at: 2.days.from_now)
    token.update!(dbsc_challenge: "stale-challenge", dbsc_challenge_issued_at: nil)
    private_key = OpenSSL::PKey::EC.generate("prime256v1")
    public_jwk = JWT::JWK.new(private_key).export

    proof = JWT.encode(
      { "jti" => "stale-challenge", "aud" => "https://test.host/registration", "iat" => Time.current.to_i },
      private_key, "ES256", { typ: "dbsc+jwt", jwk: public_jwk },
    )

    result = Dbsc::RegistrationService.call(record: token, proof: proof, session_id: "dbsc-session-y")

    assert_not result[:ok]
    assert_equal "challenge_expired", result[:error_code]
  end
end

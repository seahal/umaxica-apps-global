# typed: false
# frozen_string_literal: true

require "test_helper"

class DbscProofValidatorTest < ActiveSupport::TestCase
  # Builds a validator whose `proof` is signed by `key` with `algorithm`, so
  # verify_signature exercises the real JWT path against the matching key.
  def validator_for(key, algorithm)
    public_jwk = JWT::JWK.new(key).export
    proof = JWT.encode(
      { "jti" => "c", "aud" => "https://test.host/x", "iat" => Time.current.to_i },
      key, algorithm, { typ: "dbsc+jwt", jwk: public_jwk },
    )
    DbscProofValidator.new(
      proof: proof, challenge: "c", challenge_issued_at: Time.current,
    )
  end

  # Boundary value analysis on the RSA modulus floor (RSA_MIN_KEY_BITS = 2048).
  test "RS256 with a 2048-bit key is accepted (at the floor)" do
    key = OpenSSL::PKey::RSA.generate(2048)
    result = validator_for(key, "RS256").verify_signature(key, "RS256")

    assert_predicate result, :ok
  end

  test "RS256 with a 3072-bit key is accepted (above the floor)" do
    key = OpenSSL::PKey::RSA.generate(3072)
    result = validator_for(key, "RS256").verify_signature(key, "RS256")

    assert_predicate result, :ok
  end

  test "RS256 with a 1024-bit key is rejected (below the floor)" do
    short_key = OpenSSL::PKey::RSA.generate(1024)
    # The JWT gem refuses to even sign with a sub-2048 RSA key, so we can't
    # build a 1024-bit proof. The guard runs before JWT.decode, so verifying any
    # proof against the short key is enough to exercise the floor: sign the proof
    # with a compliant key and present the short key as the verification key.
    validator = validator_for(OpenSSL::PKey::RSA.generate(2048), "RS256")
    result = validator.verify_signature(short_key, "RS256")

    assert_not result.ok
    assert_equal "rsa_key_too_short", result.message
  end

  test "ES256 keys are not subject to the RSA floor" do
    key = OpenSSL::PKey::EC.generate("prime256v1")
    result = validator_for(key, "ES256").verify_signature(key, "ES256")

    assert_predicate result, :ok
  end
end

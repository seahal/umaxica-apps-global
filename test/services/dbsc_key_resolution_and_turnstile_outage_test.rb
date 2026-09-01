# typed: false
# frozen_string_literal: true

require "test_helper"

# Two boundaries that must fail closed rather than fall through.
#
# DBSC binds a session to a key the device holds privately, so a stored JWK that
# yields no verification key has to raise rather than leave the session
# unverifiable-but-accepted. And the challenge verifier has to report an outage
# as a failure rather than let the exception escape into the request.
class DbscKeyResolutionAndTurnstileOutageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a record whose class declares no DBSC status class is named in the error" do
    error = assert_raises(ArgumentError) { DbscRecordAdapter.dbsc_status_class(Object.new) }

    assert_match(/Unsupported DBSC status class for Object/, error.message)

    binding_error = assert_raises(ArgumentError) { DbscRecordAdapter.binding_method_class(Object.new) }

    assert_match(/Unsupported DBSC binding method class for Object/, binding_error.message)
  end

  test "a symmetric or unparsable stored key is refused rather than used to verify" do
    blank =
      assert_raises(DbscRecordAdapter::PublicKeyError) do
        DbscRecordAdapter.verification_key_from_jwk(nil, source: "client_token:1")
      end

    assert_match(/client_token:1 is not a parsable JWK/, blank.message)

    symmetric =
      assert_raises(DbscRecordAdapter::PublicKeyError) do
        DbscRecordAdapter.verification_key_from_jwk({ "kty" => "oct", "k" => "c2VjcmV0" }, source: "client_token:1")
      end

    assert_match(/must be an asymmetric JWK/, symmetric.message)

    unimportable =
      assert_raises(DbscRecordAdapter::PublicKeyError) do
        DbscRecordAdapter.verification_key_from_jwk({ "kty" => "EC" }, source: "client_token:1")
      end

    assert_match(/client_token:1/, unimportable.message)
  end

  test "an asymmetric stored key resolves to a usable verification key" do
    key = OpenSSL::PKey::EC.generate("secp384r1")
    jwk = JWT::JWK.new(key).export.stringify_keys

    assert DbscRecordAdapter.verification_key_from_jwk(jwk, source: "client_token:1")
  end

  # An unreachable challenge provider is an outage, not a failed challenge: it is
  # reported as unavailable so the caller can tell the two apart.
  test "an unreachable challenge provider is reported as an outage rather than raised" do
    verifier = JitSecurityTurnstileVerifier.new(token: "token", remote_ip: "127.0.0.1", secret_key: "secret")
    verifier.define_singleton_method(:perform_request) { raise Errno::ECONNREFUSED, "provider unreachable" }

    result = verifier.verify

    assert_not result["success"]
    assert result["unavailable"], "the caller has to tell an outage apart from a failed challenge"
  end

  test "a missing token or secret is a failure rather than a silent pass" do
    no_token = JitSecurityTurnstileVerifier.new(token: "", remote_ip: "127.0.0.1", secret_key: "secret")

    assert_not no_token.verify["success"]

    no_secret = JitSecurityTurnstileVerifier.new(token: "token", remote_ip: "127.0.0.1", secret_key: "")

    assert_not no_secret.verify["success"]
  end
end

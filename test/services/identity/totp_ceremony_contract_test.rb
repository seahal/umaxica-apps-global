# typed: false
# frozen_string_literal: true

require "test_helper"

class Identity::TotpCeremonyContractTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
  end

  teardown do
    travel_back
  end

  test "valid grant and result serialize and verify" do
    travel_to @now do
      grant_token = Identity::TotpCeremony::Grant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)
      grant = Identity::TotpCeremony::Grant.decode(grant_token, issuer_id: acme_issuer_id, now: @now)

      assert_equal "totp_ceremony", grant["purpose"]
      assert_equal Identity::TotpCeremony::Contract.sign_audience("app"), grant["aud"]

      result_token = Identity::TotpCeremony::Result.issue(valid_result_claims, issuer_id: sign_issuer_id, now: @now)
      result = Identity::TotpCeremony::Result.decode(result_token, issuer_id: sign_issuer_id, now: @now)

      assert_equal "totp_ceremony_result", result["purpose"]
      assert_equal "totp", result["proof_method"]
      assert_equal Identity::TotpCeremony::Contract.acme_audience("app"), result["aud"]
    end
  end

  test "grant rejects binding, audience, purpose, surface, operation, expiry, and forbidden fields" do
    assert_totp_ceremony_error("actor_ref") do
      Identity::TotpCeremony::Grant.new(valid_grant_claims.except("actor_ref"), now: @now)
    end
    assert_totp_ceremony_error("aud is invalid") do
      Identity::TotpCeremony::Grant.new(valid_grant_claims.merge("aud" => "https://evil.example"), now: @now)
    end
    assert_totp_ceremony_error("purpose is invalid") do
      Identity::TotpCeremony::Grant.new(valid_grant_claims.merge("purpose" => "wrong"), now: @now)
    end
    assert_totp_ceremony_error("surface is invalid") do
      Identity::TotpCeremony::Grant.new(valid_grant_claims.merge("surface" => "com"), now: @now)
    end
    assert_totp_ceremony_error("operation is invalid") do
      Identity::TotpCeremony::Grant.new(valid_grant_claims.merge("operation" => "replacement"), now: @now)
    end
    assert_totp_ceremony_error("exp is expired") do
      Identity::TotpCeremony::Grant.new(valid_grant_claims.merge("exp" => (@now - 1.second).to_i), now: @now)
    end
    %w(private_key session_token refresh_token totp_secret raw_totp first_token recent_auth sudo
       step_up_freshness).each do |claim|
      assert_totp_ceremony_error("forbidden claims") do
        Identity::TotpCeremony::Grant.new(valid_grant_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "result rejects proof, expiry, redirect, and forbidden fields" do
    assert_totp_ceremony_error("grant_jti") do
      Identity::TotpCeremony::Result.new(valid_result_claims.except("grant_jti"), now: @now)
    end
    assert_totp_ceremony_error("proof_method is invalid") do
      Identity::TotpCeremony::Result.new(valid_result_claims.merge("proof_method" => "email_otp"), now: @now)
    end
    assert_totp_ceremony_error("expires_at is expired") do
      Identity::TotpCeremony::Result.new(
        valid_result_claims.merge("expires_at" => (@now - 1.second).to_i),
        now: @now,
      )
    end
    assert_totp_ceremony_error("unknown claims") do
      Identity::TotpCeremony::Result.new(valid_result_claims.merge("return_to" => "/settings/totps"), now: @now)
    end
    %w(private_key session_token refresh_token secret_key totp_secret raw_totp first_token recent_auth sudo
       step_up_freshness).each do |claim|
      assert_totp_ceremony_error("forbidden claims") do
        Identity::TotpCeremony::Result.new(valid_result_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "signature verification rejects wrong key and tampering" do
    travel_to @now do
      token = Identity::TotpCeremony::Grant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)

      assert_totp_ceremony_error("kid is unknown") do
        Identity::TotpCeremony::Grant.decode(token, issuer_id: "surface:ACME_COM", now: @now)
      end

      tampered_payload = valid_grant_claims.merge("actor_ref" => "attacker")
      tampered = token.split(".").tap do |parts|
        parts[1] = Base64.urlsafe_encode64(tampered_payload.to_json, padding: false)
      end.join(".")
      assert_totp_ceremony_error("token verification failed") do
        Identity::TotpCeremony::Grant.decode(tampered, issuer_id: acme_issuer_id, now: @now)
      end
    end
  end

  private

  def acme_issuer_id = Identity::TotpCeremony::Contract.acme_issuer_id("app")

  def sign_issuer_id = Identity::TotpCeremony::Contract.sign_issuer_id("app")

  def valid_grant_claims
    {
      "typ" => Identity::TotpCeremony::Grant::TOKEN_TYPE,
      "iss" => Identity::TotpCeremony::Contract.acme_issuer("app"),
      "aud" => Identity::TotpCeremony::Contract.sign_audience("app"),
      "purpose" => Identity::TotpCeremony::Grant::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "jti" => "grant-1",
      "operation" => "registration",
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
    }
  end

  def valid_result_claims
    {
      "typ" => Identity::TotpCeremony::Result::TOKEN_TYPE,
      "iss" => Identity::TotpCeremony::Contract.sign_issuer("app"),
      "aud" => Identity::TotpCeremony::Contract.acme_audience("app"),
      "purpose" => Identity::TotpCeremony::Result::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "grant_jti" => "grant-1",
      "result_jti" => "result-1",
      "operation" => "registration",
      "proof_method" => Identity::TotpCeremony::Result::PROOF_METHOD,
      "verified_at" => @now.to_i,
      "challenge_id" => "challenge-1",
      "expires_at" => (@now + 10.minutes).to_i,
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
      "credential_candidate_ref" => "candidate-1",
      "credential_candidate_digest" => "candidate-digest-1",
    }
  end

  def assert_totp_ceremony_error(message)
    error = assert_raises(Identity::TotpCeremony::Error) { yield }
    assert_includes error.message, message
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Identity::EmailCeremonyContractTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
  end

  teardown do
    travel_back
  end

  test "valid grant and result serialize and verify" do
    travel_to @now do
      grant_token = Identity::EmailCeremony::Grant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)
      grant = Identity::EmailCeremony::Grant.decode(grant_token, issuer_id: acme_issuer_id, now: @now)

      assert_equal "email_ceremony", grant["purpose"]
      assert_equal Identity::EmailCeremony::Contract.sign_audience("app"), grant["aud"]

      result_token = Identity::EmailCeremony::Result.issue(valid_result_claims, issuer_id: sign_issuer_id, now: @now)
      result = Identity::EmailCeremony::Result.decode(result_token, issuer_id: sign_issuer_id, now: @now)

      assert_equal "email_ceremony_result", result["purpose"]
      assert_equal "email_otp", result["proof_method"]
      assert_equal Identity::EmailCeremony::Contract.acme_audience("app"), result["aud"]
    end
  end

  test "grant rejects binding, audience, purpose, surface, operation, expiry, and forbidden fields" do
    assert_email_ceremony_error("actor_ref") do
      Identity::EmailCeremony::Grant.new(valid_grant_claims.except("actor_ref"), now: @now)
    end
    assert_email_ceremony_error("aud is invalid") do
      Identity::EmailCeremony::Grant.new(valid_grant_claims.merge("aud" => "https://evil.example"), now: @now)
    end
    assert_email_ceremony_error("purpose is invalid") do
      Identity::EmailCeremony::Grant.new(valid_grant_claims.merge("purpose" => "wrong"), now: @now)
    end
    assert_email_ceremony_error("surface is invalid") do
      Identity::EmailCeremony::Grant.new(valid_grant_claims.merge("surface" => "bad"), now: @now)
    end
    assert_email_ceremony_error("operation is invalid") do
      Identity::EmailCeremony::Grant.new(valid_grant_claims.merge("operation" => "delete"), now: @now)
    end
    assert_email_ceremony_error("exp is expired") do
      Identity::EmailCeremony::Grant.new(valid_grant_claims.merge("exp" => (@now - 1.second).to_i), now: @now)
    end
    %w(otp otp_digest session_token refresh_token raw_address recent_auth sudo step_up_freshness).each do |claim|
      assert_email_ceremony_error("forbidden claims") do
        Identity::EmailCeremony::Grant.new(valid_grant_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "result rejects binding, proof, expiry, redirect, and forbidden fields" do
    assert_email_ceremony_error("grant_jti") do
      Identity::EmailCeremony::Result.new(valid_result_claims.except("grant_jti"), now: @now)
    end
    assert_email_ceremony_error("proof_method is invalid") do
      Identity::EmailCeremony::Result.new(valid_result_claims.merge("proof_method" => "sms_otp"), now: @now)
    end
    assert_email_ceremony_error("expires_at is expired") do
      Identity::EmailCeremony::Result.new(valid_result_claims.merge("expires_at" => (@now - 1.second).to_i), now: @now)
    end
    assert_email_ceremony_error("unknown claims") do
      Identity::EmailCeremony::Result.new(valid_result_claims.merge("return_to" => "/settings/emails"), now: @now)
    end
    %w(otp otp_digest session_token refresh_token email_address recent_auth sudo step_up_freshness).each do |claim|
      assert_email_ceremony_error("forbidden claims") do
        Identity::EmailCeremony::Result.new(valid_result_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "signature verification rejects wrong key and tampering" do
    travel_to @now do
      token = Identity::EmailCeremony::Grant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)

      assert_email_ceremony_error("kid is unknown") do
        Identity::EmailCeremony::Grant.decode(token, issuer_id: "surface:ACME_COM", now: @now)
      end

      tampered_payload = valid_grant_claims.merge("actor_ref" => "attacker")
      tampered = token.split(".").tap do |parts|
        parts[1] = Base64.urlsafe_encode64(tampered_payload.to_json, padding: false)
      end.join(".")
      assert_email_ceremony_error("token verification failed") do
        Identity::EmailCeremony::Grant.decode(tampered, issuer_id: acme_issuer_id, now: @now)
      end
    end
  end

  private

  def acme_issuer_id = Identity::EmailCeremony::Contract.acme_issuer_id("app")

  def sign_issuer_id = Identity::EmailCeremony::Contract.sign_issuer_id("app")

  def valid_grant_claims
    {
      "typ" => Identity::EmailCeremony::Grant::TOKEN_TYPE,
      "iss" => Identity::EmailCeremony::Contract.acme_issuer("app"),
      "aud" => Identity::EmailCeremony::Contract.sign_audience("app"),
      "purpose" => Identity::EmailCeremony::Grant::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "jti" => "grant-1",
      "operation" => "registration",
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
      "email_candidate_ref" => "candidate-1",
      "normalized_email_digest" => "digest-1",
    }
  end

  def valid_result_claims
    {
      "typ" => Identity::EmailCeremony::Result::TOKEN_TYPE,
      "iss" => Identity::EmailCeremony::Contract.sign_issuer("app"),
      "aud" => Identity::EmailCeremony::Contract.acme_audience("app"),
      "purpose" => Identity::EmailCeremony::Result::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "grant_jti" => "grant-1",
      "result_jti" => "result-1",
      "operation" => "registration",
      "proof_method" => Identity::EmailCeremony::Result::PROOF_METHOD,
      "verified_at" => @now.to_i,
      "challenge_id" => "challenge-1",
      "expires_at" => (@now + 10.minutes).to_i,
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
      "email_candidate_ref" => "candidate-1",
      "normalized_email_digest" => "digest-1",
    }
  end

  def assert_email_ceremony_error(message)
    error = assert_raises(Identity::EmailCeremony::Error) { yield }
    assert_includes error.message, message
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Identity::SocialCeremonyContractTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
  end

  teardown do
    travel_back
  end

  test "valid grant and result serialize and verify" do
    travel_to @now do
      grant_token = Identity::SocialCeremony::Grant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)
      grant = Identity::SocialCeremony::Grant.decode(grant_token, issuer_id: acme_issuer_id, now: @now)

      assert_equal "social_ceremony", grant["purpose"]
      assert_equal Identity::SocialCeremony::Contract.sign_audience("app"), grant["aud"]

      result_token = Identity::SocialCeremony::Result.issue(valid_result_claims, issuer_id: sign_issuer_id, now: @now)
      result = Identity::SocialCeremony::Result.decode(result_token, issuer_id: sign_issuer_id, now: @now)

      assert_equal "social_ceremony_result", result["purpose"]
      assert_equal "provider_subject", result["proof_method"]
      assert_equal Identity::SocialCeremony::Contract.acme_audience("app"), result["aud"]
    end
  end

  test "login operation allows candidate reference without provider token claims" do
    travel_to @now do
      grant_claims = valid_grant_claims.merge("operation" => "login", "actor_ref" => "anonymous")
      grant_token = Identity::SocialCeremony::Grant.issue(grant_claims, issuer_id: acme_issuer_id, now: @now)
      grant = Identity::SocialCeremony::Grant.decode(grant_token, issuer_id: acme_issuer_id, now: @now)

      assert_equal "login", grant["operation"]
      assert_equal "anonymous", grant["actor_ref"]

      result_claims = valid_result_claims.merge(
        "operation" => "login",
        "actor_ref" => "anonymous",
        "candidate_ref" => "candidate-1",
        "candidate_digest" => "candidate-digest-1",
      )
      result_token = Identity::SocialCeremony::Result.issue(result_claims, issuer_id: sign_issuer_id, now: @now)
      result = Identity::SocialCeremony::Result.decode(result_token, issuer_id: sign_issuer_id, now: @now)

      assert_equal "login", result["operation"]
      assert_equal "candidate-1", result["candidate_ref"]
      assert_equal "candidate-digest-1", result["candidate_digest"]
      assert_not_includes result.to_json, "access_token"
      assert_not_includes result.to_json, "refresh_token"
    end
  end

  test "candidate store is one-shot and keeps provider tokens server-side" do
    travel_to(@now) do
      auth_hash = OmniAuth::AuthHash.new(
        provider: "google_app",
        uid: "candidate-google",
        credentials: {
          token: "candidate-access-token",
          refresh_token: "candidate-refresh-token",
        },
      )
      candidate = Identity::SocialCeremony::CandidateStore.store!(
        surface: "app",
        actor_ref: "anonymous",
        session_ref: "session-1",
        transaction_id: "txn-1",
        operation: "login",
        provider: "google_app",
        auth_hash: auth_hash,
        expires_at: @now + 5.minutes,
      )

      fetched = Identity::SocialCeremony::CandidateStore.fetch!(candidate.ref)

      assert_equal "candidate-access-token", fetched.auth_hash.dig("credentials", "token")
      assert_equal candidate.digest, fetched.digest

      consumed = Identity::SocialCeremony::CandidateStore.consume!(candidate.ref)

      assert_equal candidate.ref, consumed.ref
      assert_social_ceremony_error("candidate is not found") do
        Identity::SocialCeremony::CandidateStore.fetch!(candidate.ref)
      end
    end
  ensure
    Identity::SocialCeremony::CandidateStore.store = nil
  end

  test "grant rejects binding, provider, audience, purpose, surface, operation, expiry, and forbidden fields" do
    assert_social_ceremony_error("actor_ref") do
      Identity::SocialCeremony::Grant.new(valid_grant_claims.except("actor_ref"), now: @now)
    end
    assert_social_ceremony_error("provider is invalid") do
      Identity::SocialCeremony::Grant.new(valid_grant_claims.merge("provider" => "github"), now: @now)
    end
    assert_social_ceremony_error("aud is invalid") do
      Identity::SocialCeremony::Grant.new(valid_grant_claims.merge("aud" => "https://evil.example"), now: @now)
    end
    assert_social_ceremony_error("purpose is invalid") do
      Identity::SocialCeremony::Grant.new(valid_grant_claims.merge("purpose" => "wrong"), now: @now)
    end
    assert_social_ceremony_error("surface is invalid") do
      Identity::SocialCeremony::Grant.new(valid_grant_claims.merge("surface" => "org"), now: @now)
    end
    assert_social_ceremony_error("operation is invalid") do
      Identity::SocialCeremony::Grant.new(valid_grant_claims.merge("operation" => "signin"), now: @now)
    end
    assert_social_ceremony_error("exp is expired") do
      Identity::SocialCeremony::Grant.new(valid_grant_claims.merge("exp" => (@now - 1.second).to_i), now: @now)
    end
    %w(access_token id_token refresh_token session_token token recent_auth sudo step_up_freshness
       raw_email).each do |claim|
      assert_social_ceremony_error("forbidden claims") do
        Identity::SocialCeremony::Grant.new(valid_grant_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "result rejects proof, expiry, redirect, and forbidden fields" do
    assert_social_ceremony_error("grant_jti") do
      Identity::SocialCeremony::Result.new(valid_result_claims.except("grant_jti"), now: @now)
    end
    assert_social_ceremony_error("proof_method is invalid") do
      Identity::SocialCeremony::Result.new(valid_result_claims.merge("proof_method" => "oauth_token"), now: @now)
    end
    assert_social_ceremony_error("expires_at is expired") do
      Identity::SocialCeremony::Result.new(
        valid_result_claims.merge("expires_at" => (@now - 1.second).to_i),
        now: @now,
      )
    end
    assert_social_ceremony_error("unknown claims") do
      Identity::SocialCeremony::Result.new(valid_result_claims.merge("return_to" => "/settings"), now: @now)
    end
    %w(access_token id_token refresh_token session_token token recent_auth sudo step_up_freshness
       raw_email).each do |claim|
      assert_social_ceremony_error("forbidden claims") do
        Identity::SocialCeremony::Result.new(valid_result_claims.merge(claim => "secret"), now: @now)
      end
    end
  end

  test "signature verification rejects wrong key and tampering" do
    travel_to @now do
      token = Identity::SocialCeremony::Grant.issue(valid_grant_claims, issuer_id: acme_issuer_id, now: @now)

      assert_social_ceremony_error("kid is unknown") do
        Identity::SocialCeremony::Grant.decode(token, issuer_id: "surface:ACME_COM", now: @now)
      end

      tampered_payload = valid_grant_claims.merge("actor_ref" => "attacker")
      tampered = token.split(".").tap do |parts|
        parts[1] = Base64.urlsafe_encode64(tampered_payload.to_json, padding: false)
      end.join(".")
      assert_social_ceremony_error("token verification failed") do
        Identity::SocialCeremony::Grant.decode(tampered, issuer_id: acme_issuer_id, now: @now)
      end
    end
  end

  private

  def acme_issuer_id = Identity::SocialCeremony::Contract.acme_issuer_id("app")

  def sign_issuer_id = Identity::SocialCeremony::Contract.sign_issuer_id("app")

  def valid_grant_claims
    {
      "typ" => Identity::SocialCeremony::Grant::TOKEN_TYPE,
      "iss" => Identity::SocialCeremony::Contract.acme_issuer("app"),
      "aud" => Identity::SocialCeremony::Contract.sign_audience("app"),
      "purpose" => Identity::SocialCeremony::Grant::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "jti" => "grant-1",
      "operation" => "link",
      "provider" => "google_app",
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
    }
  end

  def valid_result_claims
    {
      "typ" => Identity::SocialCeremony::Result::TOKEN_TYPE,
      "iss" => Identity::SocialCeremony::Contract.sign_issuer("app"),
      "aud" => Identity::SocialCeremony::Contract.acme_audience("app"),
      "purpose" => Identity::SocialCeremony::Result::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "grant_jti" => "grant-1",
      "result_jti" => "result-1",
      "operation" => "link",
      "provider" => "google_app",
      "proof_method" => Identity::SocialCeremony::Result::PROOF_METHOD,
      "provider_subject_ref" => "subject-digest",
      "provider_subject_digest" => "subject-digest",
      "verified_at" => @now.to_i,
      "challenge_id" => "challenge-1",
      "expires_at" => (@now + 10.minutes).to_i,
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
    }
  end

  def assert_social_ceremony_error(message)
    error = assert_raises(Identity::SocialCeremony::Error) { yield }
    assert_includes error.message, message
  end
end

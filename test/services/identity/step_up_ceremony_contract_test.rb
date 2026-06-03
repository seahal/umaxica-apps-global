# typed: false
# frozen_string_literal: true

require "test_helper"

class Identity::StepUpCeremonyContractTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
    @client = clients(:one)
    @token = ClientToken.create!(
      user: @client,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
  end

  teardown do
    travel_back
  end

  test "valid grant and result serialize and verify" do
    travel_to @now do
      grant_token = Identity::StepUpCeremony::Grant.issue(
        valid_grant_claims,
        issuer_id: Identity::StepUpCeremony::Contract.acme_issuer_id("app"),
        now: @now,
      )
      grant = Identity::StepUpCeremony::Grant.decode(
        grant_token,
        issuer_id: Identity::StepUpCeremony::Contract.acme_issuer_id("app"),
        now: @now,
      )

      assert_equal "step_up_ceremony", grant["purpose"]
      assert_equal "settings_email", grant["required_scope"]

      result_token = Identity::StepUpCeremony::Result.issue(
        valid_result_claims,
        issuer_id: Identity::StepUpCeremony::Contract.sign_issuer_id("app"),
        now: @now,
      )
      result = Identity::StepUpCeremony::Result.decode(
        result_token,
        issuer_id: Identity::StepUpCeremony::Contract.sign_issuer_id("app"),
        now: @now,
      )

      assert_equal "step_up_ceremony_result", result["purpose"]
      assert_equal "totp", result["method"]
    end
  end

  test "result rejects forbidden freshness and secret claims" do
    %w(otp otp_digest session_token refresh_token recent_auth sudo step_up_freshness totp_secret).each do |claim|
      error =
        assert_raises(Identity::StepUpCeremony::Error) do
          Identity::StepUpCeremony::Result.new(valid_result_claims.merge(claim => "secret"), now: @now)
        end
      assert_includes error.message, "forbidden claims"
    end
  end

  test "freshness committer writes token freshness and rejects replay mismatches" do
    travel_to @now do
      result_token = Identity::StepUpCeremony::Result.issue(
        valid_result_claims,
        issuer_id: Identity::StepUpCeremony::Contract.sign_issuer_id("app"),
        now: @now,
      )

      Identity::StepUpCeremony::FreshnessCommitter.call!(
        result_token: result_token,
        token: @token,
        expected_scope: "settings_email",
        expected_aal: "aal2",
        expected_method: "totp",
        audience: "step_up:app",
        now: @now,
      )

      @token.reload

      assert_equal @now.to_i, @token.last_step_up_at.to_i
      assert_equal "settings_email", @token.last_step_up_scope
      assert_equal "aal2", @token.last_step_up_aal
      assert_equal "totp", @token.last_step_up_method
      assert_equal "step_up", @token.last_step_up_purpose
      assert_equal "step_up:app", @token.last_step_up_audience

      assert_raises(Identity::StepUpCeremony::Error) do
        Identity::StepUpCeremony::FreshnessCommitter.call!(
          result_token: result_token,
          token: @token,
          expected_scope: "settings_telephone",
          expected_aal: "aal2",
          expected_method: "totp",
          audience: "step_up:app",
          now: @now,
        )
      end
    end
  end

  private

  def valid_grant_claims
    {
      "typ" => Identity::StepUpCeremony::Grant::TOKEN_TYPE,
      "iss" => Identity::StepUpCeremony::Contract.acme_issuer("app"),
      "aud" => Identity::StepUpCeremony::Contract.sign_audience("app"),
      "purpose" => Identity::StepUpCeremony::Grant::PURPOSE,
      "surface" => "app",
      "actor_ref" => @client.public_id,
      "session_ref" => @token.public_id,
      "transaction_id" => "step-up-txn",
      "jti" => "step-up-grant",
      "required_scope" => "settings_email",
      "required_aal" => "aal2",
      "allowed_methods" => %w(totp passkey email_otp),
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
    }
  end

  def valid_result_claims
    {
      "typ" => Identity::StepUpCeremony::Result::TOKEN_TYPE,
      "iss" => Identity::StepUpCeremony::Contract.sign_issuer("app"),
      "aud" => Identity::StepUpCeremony::Contract.acme_audience("app"),
      "purpose" => Identity::StepUpCeremony::Result::PURPOSE,
      "surface" => "app",
      "actor_ref" => @client.public_id,
      "session_ref" => @token.public_id,
      "transaction_id" => "step-up-txn",
      "grant_jti" => "step-up-grant",
      "result_jti" => SecureRandom.uuid,
      "scope" => "settings_email",
      "aal" => "aal2",
      "method" => "totp",
      "verified_at" => @now.to_i,
      "challenge_id" => "challenge-1",
      "expires_at" => (@now + 10.minutes).to_i,
      "iat" => @now.to_i,
      "exp" => (@now + 10.minutes).to_i,
    }
  end
end

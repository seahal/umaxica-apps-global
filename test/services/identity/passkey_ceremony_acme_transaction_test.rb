# typed: false
# frozen_string_literal: true

require "test_helper"

class Identity::PasskeyCeremonyAcmeTransactionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients, :client_statuses, :client_chronicle_events, :client_chronicle_levels

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
    @client = clients(:one)
    @session_ref = "session-#{SecureRandom.hex(4)}"
  end

  teardown do
    travel_back
  end

  test "grant issuance creates durable transaction and valid grant" do
    travel_to @now do
      issuance = Identity::PasskeyCeremony::GrantIssuer.issue!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: @session_ref,
        operation: "registration",
        now: @now,
      )

      grant = Identity::PasskeyCeremony::Grant.decode(
        issuance.grant,
        issuer_id: Identity::PasskeyCeremony::Contract.acme_issuer_id("app"),
        now: @now,
      )

      assert_equal issuance.transaction.transaction_id, grant["transaction_id"]
      assert_equal issuance.transaction.grant_jti, grant["jti"]
      assert_equal @client.public_id, grant["actor_ref"]
      assert_equal @session_ref, grant["session_ref"]
    end
  end

  test "valid result consumes once and commits passkey under acme authority" do
    travel_to @now do
      issuance = Identity::PasskeyCeremony::GrantIssuer.issue!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: @session_ref,
        operation: "registration",
        now: @now,
      )
      candidate = Identity::PasskeyCeremony::ResultIssuer::Candidate.new(
        webauthn_id: "passkey-ceremony-#{SecureRandom.hex(4)}",
        public_key: "public-key",
        sign_count: 0,
        description: "Ceremony Passkey",
        transports: ["internal"],
      )
      result_token = Identity::PasskeyCeremony::ResultIssuer.issue!(
        grant_token: issuance.grant,
        candidate: candidate,
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: @session_ref,
        operation: "registration",
        now: @now,
      )

      assert_difference -> { ClientPasskey.where(user: @client).count }, 1 do
        commit = Identity::PasskeyCeremony::FinalCommitter.call!(
          result_token: result_token,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          ip_address: "127.0.0.1",
          user_agent: "Rails test",
          now: @now,
        )

        assert_equal "Ceremony Passkey", commit.passkey.description
      end

      assert_predicate issuance.transaction.reload, :consumed?
      assert_raises(Identity::PasskeyCeremony::Error) do
        Identity::PasskeyCeremony::FinalCommitter.call!(
          result_token: result_token,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          ip_address: "127.0.0.1",
          user_agent: "Rails test",
          now: @now,
        )
      end
    end
  end

  test "transaction tables do not persist forbidden secret fields" do
    forbidden_columns = %w(
      private_key raw_password password session_token refresh_token otp totp_secret public_key webauthn_private_key
    )

    assert_empty ClientPasskeyCeremonyTransaction.column_names & forbidden_columns
    assert_empty VisitorPasskeyCeremonyTransaction.column_names & forbidden_columns
    assert_empty OperatorPasskeyCeremonyTransaction.column_names & forbidden_columns
  end
end

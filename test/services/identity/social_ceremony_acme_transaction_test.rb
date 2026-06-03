# typed: false
# frozen_string_literal: true

require "test_helper"

class Identity::SocialCeremonyAcmeTransactionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients, :client_statuses, :client_chronicle_events, :client_chronicle_levels,
           :client_google_identity_statuses, :client_apple_identity_statuses

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
    @client = clients(:one)
    @client.user_google_identity&.destroy!
    @session_ref = "session-#{SecureRandom.hex(4)}"
  end

  teardown do
    travel_back
  end

  test "grant issuance creates durable transaction and valid grant" do
    travel_to @now do
      issuance = issue_grant
      grant = Identity::SocialCeremony::Grant.decode(
        issuance.grant,
        issuer_id: Identity::SocialCeremony::Contract.acme_issuer_id("app"),
        now: @now,
      )

      assert_equal issuance.transaction.transaction_id, grant["transaction_id"]
      assert_equal issuance.transaction.grant_jti, grant["jti"]
      assert_equal @client.public_id, grant["actor_ref"]
      assert_equal @session_ref, grant["session_ref"]
      assert_equal "google_app", grant["provider"]
    end
  end

  test "valid result consumes once and commits social link under acme authority" do
    travel_to @now do
      issuance = issue_grant
      result_token = issue_result(issuance.grant)

      assert_difference -> { ClientGoogleIdentity.where(user: @client).count }, 1 do
        commit = Identity::SocialCeremony::FinalCommitter.call!(
          result_token: result_token,
          auth_hash: auth_hash,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          ip_address: "127.0.0.1",
          user_agent: "Rails test",
          now: @now,
        )

        assert_equal "google_app", commit.identity.provider
        assert_equal auth_hash["uid"], commit.identity.uid
      end

      assert_predicate issuance.transaction.reload, :consumed?
      assert_raises(Identity::SocialCeremony::Error) do
        Identity::SocialCeremony::FinalCommitter.call!(
          result_token: result_token,
          auth_hash: auth_hash,
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

  test "result payload and transaction table do not expose provider tokens" do
    travel_to @now do
      issuance = issue_grant
      result_token = issue_result(issuance.grant)
      payload = Identity::SocialCeremony::Contract.decode_unverified_payload(result_token)

      assert_not_includes payload.to_json, auth_hash["credentials"]["token"]
      assert_not_includes payload.to_json, auth_hash["credentials"]["refresh_token"]
      assert_not payload.key?("token")
      assert_not payload.key?("access_token")
      assert_not payload.key?("refresh_token")
      assert_not payload.key?("id_token")
    end

    forbidden_columns = %w(
      access_token id_token refresh_token session_token token raw_email provider_token provider_refresh_token
    )

    assert_empty ClientSocialCeremonyTransaction.column_names & forbidden_columns
  end

  test "wrong actor, session, and provider subject are rejected before link commit" do
    travel_to @now do
      issuance = issue_grant
      result_token = issue_result(issuance.grant)

      assert_raises(Identity::SocialCeremony::Error) do
        Identity::SocialCeremony::FinalCommitter.call!(
          result_token: result_token,
          auth_hash: auth_hash,
          actor: clients(:two),
          session_ref: @session_ref,
          surface: "app",
          now: @now,
        )
      end
      assert_raises(Identity::SocialCeremony::Error) do
        Identity::SocialCeremony::FinalCommitter.call!(
          result_token: result_token,
          auth_hash: auth_hash,
          actor: @client,
          session_ref: "wrong-session",
          surface: "app",
          now: @now,
        )
      end
      wrong_auth_hash = auth_hash.merge("uid" => "different-subject")
      assert_raises(Identity::SocialCeremony::Error) do
        Identity::SocialCeremony::FinalCommitter.call!(
          result_token: result_token,
          auth_hash: wrong_auth_hash,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          now: @now,
        )
      end

      assert_nil ClientGoogleIdentity.find_by(uid: auth_hash["uid"])
    end
  end

  test "purger removes only retained expired and consumed transactions" do
    travel_to @now do
      active = issue_grant.transaction
      expired_old = Identity::SocialCeremony::ReplayStore.for("app").create_transaction!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: "#{@session_ref}-old-expired",
        operation: "link",
        provider: "google_app",
        expires_at: @now - 8.days,
        now: @now - 9.days,
      )
      consumed_old = Identity::SocialCeremony::ReplayStore.for("app").create_transaction!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: "#{@session_ref}-old-consumed",
        operation: "link",
        provider: "google_app",
        expires_at: @now + 1.hour,
        now: @now - 9.days,
      )
      consumed_old.update!(
        status: SocialCeremonyTransactionable::STATUS_CONSUMED, result_jti: SecureRandom.uuid,
        consumed_at: @now - 8.days,
      )

      counts = Identity::SocialCeremony::TransactionPurger.new(now: @now).call

      assert_equal 2, counts.fetch("app")
      assert ClientSocialCeremonyTransaction.exists?(active.id)
      assert_not ClientSocialCeremonyTransaction.exists?(expired_old.id)
      assert_not ClientSocialCeremonyTransaction.exists?(consumed_old.id)
    end
  end

  private

  def issue_grant
    Identity::SocialCeremony::GrantIssuer.issue!(
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "link",
      provider: "google_app",
      now: @now,
    )
  end

  def issue_result(grant_token)
    Identity::SocialCeremony::ResultIssuer.issue!(
      grant_token: grant_token,
      auth_hash: auth_hash,
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "link",
      now: @now,
    )
  end

  def auth_hash
    @auth_hash ||= {
      "provider" => "google_app",
      "uid" => "social-ceremony-#{SecureRandom.hex(6)}",
      "credentials" => {
        "token" => "provider-access-token",
        "refresh_token" => "provider-refresh-token",
        "expires_at" => 1.hour.from_now.to_i,
      },
      "info" => {
        "email" => "social-ceremony@example.com",
      },
      "extra" => {
        "raw_info" => {
          "email_verified" => true,
        },
      },
    }
  end
end

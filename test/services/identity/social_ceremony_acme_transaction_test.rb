# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentitySocialCeremonyAcmeTransactionTest < ActiveSupport::TestCase
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
      grant = IdentitySocialCeremonyGrant.decode(
        issuance.grant,
        issuer_id: IdentitySocialCeremonyContract.acme_issuer_id("app"),
        now: @now,
      )

      assert_equal issuance.transaction.transaction_id, grant["transaction_id"]
      assert_equal issuance.transaction.grant_jti, grant["jti"]
      assert_equal @client.public_id, grant["actor_ref"]
      assert_equal @session_ref, grant["session_ref"]
      assert_equal "google", grant["provider"]
    end
  end

  test "valid result consumes once and commits social link under acme authority" do
    travel_to @now do
      issuance = issue_grant
      result_token = issue_result(issuance.grant)

      assert_difference -> { ClientGoogleIdentity.where(user: @client).count }, 1 do
        commit = IdentitySocialCeremonyFinalCommitter.call!(
          result_token: result_token,
          auth_hash: auth_hash,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          ip_address: "127.0.0.1",
          user_agent: "Rails test",
          now: @now,
        )

        assert_equal "google", commit.identity.provider
        assert_equal auth_hash["uid"], commit.identity.uid
      end

      assert_predicate issuance.transaction.reload, :consumed?
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyFinalCommitter.call!(
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
      payload = IdentitySocialCeremonyContract.decode_untrusted_routing_payload(result_token)

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

  test "replay store rejects invalid surface" do
    assert_raises(IdentitySocialCeremonyContract::Error) do
      IdentitySocialCeremonyReplayStore.for("invalid-surface")
    end
  end

  test "replay store raises error on missing transaction" do
    store = IdentitySocialCeremonyReplayStore.for("app")
    assert_raises(IdentitySocialCeremonyContract::Error) do
      store.find_transaction!("non-existent-id")
    end
  end

  test "wrong actor, session, and provider subject are rejected before link commit" do
    travel_to @now do
      issuance = issue_grant
      result_token = issue_result(issuance.grant)

      assert_no_difference("ClientToken.count") do
        assert_no_difference("VisitorToken.count") do
          assert_no_difference("OperatorToken.count") do
            assert_raises(IdentitySocialCeremonyContract::Error) do
              IdentitySocialCeremonyFinalCommitter.call!(
                result_token: result_token,
                auth_hash: auth_hash,
                actor: clients(:two),
                session_ref: @session_ref,
                surface: "app",
                now: @now,
              )
            end
            assert_raises(IdentitySocialCeremonyContract::Error) do
              IdentitySocialCeremonyFinalCommitter.call!(
                result_token: result_token,
                auth_hash: auth_hash,
                actor: @client,
                session_ref: "wrong-session",
                surface: "app",
                now: @now,
              )
            end
            wrong_auth_hash = auth_hash.merge("uid" => "different-subject")
            assert_raises(IdentitySocialCeremonyContract::Error) do
              IdentitySocialCeremonyFinalCommitter.call!(
                result_token: result_token,
                auth_hash: wrong_auth_hash,
                actor: @client,
                session_ref: @session_ref,
                surface: "app",
                now: @now,
              )
            end
          end
        end
      end

      assert_nil ClientGoogleIdentity.find_by(uid: auth_hash["uid"])
    end
  end

  test "purger removes only retained expired and consumed transactions" do
    travel_to @now do
      active = issue_grant.transaction
      expired_old = IdentitySocialCeremonyReplayStore.for("app").create_transaction!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: "#{@session_ref}-old-expired",
        operation: "link",
        provider: "google",
        expires_at: @now - 8.days,
        now: @now - 9.days,
      )
      consumed_old = IdentitySocialCeremonyReplayStore.for("app").create_transaction!(
        surface: "app",
        actor_ref: @client.public_id,
        session_ref: "#{@session_ref}-old-consumed",
        operation: "link",
        provider: "google",
        expires_at: @now + 1.hour,
        now: @now - 9.days,
      )
      consumed_old.update!(
        status: SocialCeremonyTransactionable::STATUS_CONSUMED, result_jti: SecureRandom.uuid,
        consumed_at: @now - 8.days,
      )

      counts = IdentitySocialCeremonyTransactionPurger.new(now: @now).call

      assert_equal 2, counts.fetch("app")
      assert ClientSocialCeremonyTransaction.exists?(active.id)
      assert_not ClientSocialCeremonyTransaction.exists?(expired_old.id)
      assert_not ClientSocialCeremonyTransaction.exists?(consumed_old.id)
    end
  end

  # Invariant: the untrusted routing payload is attacker-controlled, but the
  # verified ceremony path is the only thing that can authorize a commit.
  test "tampering the untrusted payload cannot commit a social link without a valid verified result" do
    travel_to @now do
      issuance = issue_grant
      result_token = issue_result(issuance.grant)

      # Forge a token: keep the original (valid) signature but rewrite the
      # payload claims an attacker would want to control.
      tampered = tamper_payload(
        result_token,
        "operation" => "login",
        "session_ref" => "attacker-session",
        "actor_ref" => clients(:two).public_id,
      )

      # Untrusted decode reflects the attacker's claims (by design: it is untrusted).
      forged = IdentitySocialCeremonyContract.decode_untrusted_routing_payload(tampered)

      assert_equal "login", forged["operation"]
      assert_equal "attacker-session", forged["session_ref"]

      # The verified path rejects the forged token: signature no longer matches.
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyFinalCommitter.call!(
          result_token: tampered,
          auth_hash: auth_hash,
          actor: @client,
          session_ref: @session_ref,
          surface: "app",
          now: @now,
        )
      end

      assert_nil ClientGoogleIdentity.find_by(uid: auth_hash["uid"])
      assert_not_predicate issuance.transaction.reload, :consumed?
    end
  end

  test "untrusted operation cannot route a verified link token into a login commit" do
    travel_to @now do
      issuance = issue_grant
      # Genuine, untampered link result token.
      result_token = issue_result(issuance.grant)

      # The acme login path passes actor: nil. Even though an attacker could flip
      # the UNVERIFIED operation to "login" to slip past the controller's link
      # rejection, the committer derives operation from the VERIFIED result
      # ("link") and rejects because a link requires an actor.
      error =
        assert_raises(IdentitySocialCeremonyContract::Error) do
          IdentitySocialCeremonyFinalCommitter.call!(
            result_token: result_token,
            auth_hash: auth_hash,
            actor: nil,
            session_ref: @session_ref,
            surface: "app",
            now: @now,
          )
        end

      assert_equal "actor is required", error.message
      assert_nil ClientGoogleIdentity.find_by(uid: auth_hash["uid"])
      assert_not_predicate issuance.transaction.reload, :consumed?
    end
  end

  private

  # Rewrites the payload segment of a JWS while leaving the original signature in
  # place, simulating an attacker tampering with claims they cannot re-sign.
  def tamper_payload(token, overrides)
    header_b64, payload_b64, signature_b64 = token.split(".")
    payload = JSON.parse(url_b64_decode(payload_b64)).merge(overrides)
    [header_b64, url_b64_encode(payload.to_json), signature_b64].join(".")
  end

  def url_b64_decode(segment)
    Base64.urlsafe_decode64(segment + ("=" * ((4 - (segment.length % 4)) % 4)))
  end

  def url_b64_encode(bytes)
    Base64.urlsafe_encode64(bytes, padding: false)
  end

  def issue_grant
    IdentitySocialCeremonyGrantIssuer.issue!(
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @session_ref,
      operation: "link",
      provider: "google",
      now: @now,
    )
  end

  def issue_result(grant_token)
    IdentitySocialCeremonyResultIssuer.issue!(
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
      "provider" => "google",
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

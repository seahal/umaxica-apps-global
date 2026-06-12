# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientSecretCredentialsIssueRecoveryTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_email_statuses, :client_secret_credential_kinds,
           :client_secret_credential_statuses

  setup do
    @actor = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "scu_#{SecureRandom.hex(4)}",
    )
    ClientEmail.create!(
      user: @actor,
      address: "recovery-issue-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
  end

  test "issues new-axis recovery secret and consumes it once" do
    result = ClientSecretCredentialsIssueRecovery.call(actor: @actor, user: @actor)

    assert_predicate result.secret_credential, :persisted?
    assert_predicate result.secret_credential, :new_axis_secret_credential?
    assert_equal "recovery", result.secret_credential.secret_kind
    assert_equal "single_use", result.secret_credential.usage_policy
    assert_equal ClientSecretCredentialKind::RECOVERY, result.secret_credential.user_secret_kind_id
    assert_equal Sign::Secret::LookupDigest.digest(result.raw_secret_credential), result.secret_credential.lookup_digest
    assert_not_includes result.secret_credential.attributes.values, result.raw_secret_credential

    verification = Sign::Secret::Verify.call(
      secret_credential: result.secret_credential,
      raw_secret_credential: result.raw_secret_credential,
    )

    assert_predicate verification.secret_credential, :present?
    assert_predicate result.secret_credential.reload.consumed_at, :present?
    assert_equal 1, result.secret_credential.reload.use_count

    repeat = Sign::Secret::Verify.call(
      secret_credential: result.secret_credential.reload,
      raw_secret_credential: result.raw_secret_credential,
    )

    assert_nil repeat.secret_credential
    assert_equal :secret_credential_consumed, repeat.reason
  end

  test "revoked and discarded new-axis recovery secrets cannot be used" do
    result = ClientSecretCredentialsIssueRecovery.call(actor: @actor, user: @actor)

    Sign::Secret::Revoke.call(secret_credential: result.secret_credential)
    revoked = Sign::Secret::Verify.call(
      secret_credential: result.secret_credential.reload,
      raw_secret_credential: result.raw_secret_credential,
    )

    assert_nil revoked.secret_credential
    assert_equal :secret_credential_revoked, revoked.reason

    fresh = ClientSecretCredentialsIssueRecovery.call(actor: @actor, user: @actor)
    fresh.secret_credential.update_columns(discarded_at: 1.minute.ago)

    expired = Sign::Secret::Verify.call(
      secret_credential: fresh.secret_credential.reload,
      raw_secret_credential: fresh.raw_secret_credential,
    )

    assert_nil expired.secret_credential
    assert_equal :secret_credential_expired, expired.reason
  end

  test "future discarded_at remains usable and purged_at is ignored for eligibility" do
    result = ClientSecretCredentialsIssueRecovery.call(actor: @actor, user: @actor)
    result.secret_credential.update_columns(discarded_at: 10.minutes.from_now, purged_at: 1.minute.ago)

    verification = Sign::Secret::Verify.call(
      secret_credential: result.secret_credential.reload,
      raw_secret_credential: result.raw_secret_credential,
    )

    assert_predicate verification.secret_credential, :present?
  end
end

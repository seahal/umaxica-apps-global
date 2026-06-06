# typed: false
# frozen_string_literal: true

require "test_helper"

class SignAppUpSocialCancellationTest < ActiveSupport::TestCase
  fixtures_none!

  setup do
    ClientStatus.ensure_defaults!
    ClientMfaLevel.ensure_defaults!
    ClientMfaStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    ClientSignUpFlowStatus.ensure_defaults!
    ClientGoogleIdentityStatus.ensure_defaults!
    ClientAppleIdentityStatus.ensure_defaults!
  end

  test "cancels google sign up and schedules pending identity and actor retention" do
    user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    identity = ClientGoogleIdentity.create!(
      user: user,
      uid: "cancel-google-sign-up",
      provider: "google_app",
      token: "token",
      token_expires_at: 1.week.from_now.to_i,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    cycle = social_cycle(user, identity, provider: "google")

    result = SignAppUpSocialCancellation.call(cycle: cycle)

    assert_predicate result, :success?
    assert_equal ClientSignUpFlowStatus::CANCELLED, cycle.reload.status_id
    assert Client.exists?(user.id)
    assert ClientGoogleIdentity.exists?(identity.id)
    assert_not user.reload.accessible?
    assert_equal ClientGoogleIdentityStatus::DELETED, identity.reload.status_id
    assert_not_infinite_time identity.discarded_at
    assert_operator identity.purged_at, :>, identity.discarded_at
  end

  test "cancels apple sign up and schedules pending identity and actor retention" do
    user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    identity = ClientAppleIdentity.create!(
      user: user,
      uid: "cancel-apple-sign-up",
      provider: "apple",
      token: "token",
      token_expires_at: 1.week.from_now.to_i,
      status_id: ClientAppleIdentityStatus::ACTIVE,
    )
    cycle = social_cycle(user, identity, provider: "apple")

    result = SignAppUpSocialCancellation.call(cycle: cycle)

    assert_predicate result, :success?
    assert_equal ClientSignUpFlowStatus::CANCELLED, cycle.reload.status_id
    assert Client.exists?(user.id)
    assert ClientAppleIdentity.exists?(identity.id)
    assert_not user.reload.accessible?
    assert_equal ClientAppleIdentityStatus::DELETED, identity.reload.status_id
    assert_not_infinite_time identity.discarded_at
    assert_operator identity.purged_at, :>, identity.discarded_at
  end

  test "does not remove registered actor or identity" do
    user = Client.create!(status_id: ClientStatus::ACTIVE)
    identity = ClientGoogleIdentity.create!(
      user: user,
      uid: "keep-registered-google",
      provider: "google_app",
      token: "token",
      token_expires_at: 1.week.from_now.to_i,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    cycle = social_cycle(user, identity, provider: "google")

    result = SignAppUpSocialCancellation.call(cycle: cycle)

    assert_predicate result, :failure?
    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, cycle.reload.status_id
    assert Client.exists?(user.id)
    assert ClientGoogleIdentity.exists?(identity.id)
  end

  test "does not remove a social identity outside the current cycle actor" do
    pending_user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    other_user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    identity = ClientGoogleIdentity.create!(
      user: other_user,
      uid: "keep-other-cycle-google",
      provider: "google_app",
      token: "token",
      token_expires_at: 1.week.from_now.to_i,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    cycle = social_cycle(pending_user, identity, provider: "google")

    result = SignAppUpSocialCancellation.call(cycle: cycle)

    assert_predicate result, :failure?
    assert_equal ClientSignUpFlowStatus::CHECKPOINT_PENDING, cycle.reload.status_id
    assert Client.exists?(pending_user.id)
    assert Client.exists?(other_user.id)
    assert ClientGoogleIdentity.exists?(identity.id)
  end

  private

  def assert_not_infinite_time(value)
    assert_not(value.respond_to?(:infinite?) && value.infinite?)
  end

  def social_cycle(user, identity, provider:)
    ClientSignUpFlow.create!(
      principal_id: user.id,
      status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      nonce_digest: ClientSignUpFlow.digest_nonce("nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: provider,
      social_provider: provider,
      pending_contact_type: "social_identity",
      pending_contact_id: identity.id,
    )
  end
end

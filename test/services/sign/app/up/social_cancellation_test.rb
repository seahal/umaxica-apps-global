# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Up::SocialCancellationTest < ActiveSupport::TestCase
  fixtures_none!

  setup do
    ClientStatus.ensure_defaults!
    ClientMultiFactor.ensure_defaults!
    ClientMultiFactorStatus.ensure_defaults!
    ClientVisibility.ensure_defaults!
    ClientSignUpCycleStatus.ensure_defaults!
    ClientSocialGoogleStatus.ensure_defaults!
    ClientSocialAppleStatus.ensure_defaults!
  end

  test "cancels google sign up and schedules pending identity and actor retention" do
    user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    identity = ClientSocialGoogle.create!(
      user: user,
      uid: "cancel-google-sign-up",
      provider: "google_app",
      token: "token",
      token_expires_at: 1.week.from_now.to_i,
      status_id: ClientSocialGoogleStatus::ACTIVE,
    )
    cycle = social_cycle(user, identity, provider: "google")

    result = Sign::App::Up::SocialCancellation.call(cycle: cycle)

    assert_predicate result, :success?
    assert_equal ClientSignUpCycleStatus::CANCELLED, cycle.reload.status_id
    assert Client.exists?(user.id)
    assert ClientSocialGoogle.exists?(identity.id)
    assert_not user.reload.accessible?
    assert_equal ClientSocialGoogleStatus::DELETED, identity.reload.status_id
    assert_not_infinite_time identity.discarded_at
    assert_operator identity.purged_at, :>, identity.discarded_at
  end

  test "cancels apple sign up and schedules pending identity and actor retention" do
    user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    identity = ClientSocialApple.create!(
      user: user,
      uid: "cancel-apple-sign-up",
      provider: "apple",
      token: "token",
      token_expires_at: 1.week.from_now.to_i,
      status_id: ClientSocialAppleStatus::ACTIVE,
    )
    cycle = social_cycle(user, identity, provider: "apple")

    result = Sign::App::Up::SocialCancellation.call(cycle: cycle)

    assert_predicate result, :success?
    assert_equal ClientSignUpCycleStatus::CANCELLED, cycle.reload.status_id
    assert Client.exists?(user.id)
    assert ClientSocialApple.exists?(identity.id)
    assert_not user.reload.accessible?
    assert_equal ClientSocialAppleStatus::DELETED, identity.reload.status_id
    assert_not_infinite_time identity.discarded_at
    assert_operator identity.purged_at, :>, identity.discarded_at
  end

  test "does not remove registered actor or identity" do
    user = Client.create!(status_id: ClientStatus::ACTIVE)
    identity = ClientSocialGoogle.create!(
      user: user,
      uid: "keep-registered-google",
      provider: "google_app",
      token: "token",
      token_expires_at: 1.week.from_now.to_i,
      status_id: ClientSocialGoogleStatus::ACTIVE,
    )
    cycle = social_cycle(user, identity, provider: "google")

    result = Sign::App::Up::SocialCancellation.call(cycle: cycle)

    assert_predicate result, :failure?
    assert_equal ClientSignUpCycleStatus::CHECKPOINT_PENDING, cycle.reload.status_id
    assert Client.exists?(user.id)
    assert ClientSocialGoogle.exists?(identity.id)
  end

  test "does not remove a social identity outside the current cycle actor" do
    pending_user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    other_user = Client.create!(status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
    identity = ClientSocialGoogle.create!(
      user: other_user,
      uid: "keep-other-cycle-google",
      provider: "google_app",
      token: "token",
      token_expires_at: 1.week.from_now.to_i,
      status_id: ClientSocialGoogleStatus::ACTIVE,
    )
    cycle = social_cycle(pending_user, identity, provider: "google")

    result = Sign::App::Up::SocialCancellation.call(cycle: cycle)

    assert_predicate result, :failure?
    assert_equal ClientSignUpCycleStatus::CHECKPOINT_PENDING, cycle.reload.status_id
    assert Client.exists?(pending_user.id)
    assert Client.exists?(other_user.id)
    assert ClientSocialGoogle.exists?(identity.id)
  end

  private

  def assert_not_infinite_time(value)
    assert_not(value.respond_to?(:infinite?) && value.infinite?)
  end

  def social_cycle(user, identity, provider:)
    ClientSignUpCycle.create!(
      principal_id: user.id,
      status_id: ClientSignUpCycleStatus::CHECKPOINT_PENDING,
      step: "checkpoint",
      nonce_digest: ClientSignUpCycle.digest_nonce("nonce"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
      entry_method: provider,
      social_provider: provider,
      pending_contact_type: "social_identity",
      pending_contact_id: identity.id,
    )
  end
end

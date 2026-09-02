# typed: false
# frozen_string_literal: true

require "test_helper"

# A step-up grant and its result both carry the assurance level as a string on
# the wire, and both translate the "no particular level" sentinel back to nil
# rather than to a symbol named after it -- otherwise a scope that demands no
# level would be compared against a level literally called "none".
class IdentityStepUpCeremonyAalTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def issue_grant(required_aal:)
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: "app",
      actor_ref: "actor-public-id",
      session_ref: "session-public-id",
      required_scope: "settings_email",
      required_aal: required_aal,
      allowed_methods: %i(totp passkey),
      return_to: "/settings/emails",
      expires_at: 15.minutes.from_now,
    ).grant
  end

  def decode_grant(token)
    IdentityStepUpCeremonyGrant.decode(
      token,
      issuer_id: IdentityStepUpCeremonyContract.acme_issuer_id("app"),
    )
  end

  test "a grant that demands a level reports it as a symbol" do
    assert_equal :aal2, decode_grant(issue_grant(required_aal: "aal2")).required_aal
  end

  test "a grant that demands no particular level reports nothing rather than the sentinel" do
    assert_nil decode_grant(issue_grant(required_aal: StepUpRequirement::NO_AAL)).required_aal
  end

  def issue_result(aal:)
    IdentityStepUpCeremonyResultIssuer.issue!(
      surface: "app",
      actor_ref: "actor-public-id",
      session_ref: "session-public-id",
      transaction_id: SecureRandom.uuid,
      grant_jti: SecureRandom.uuid,
      scope: "settings_email",
      aal: aal,
      method: "passkey",
      challenge_id: SecureRandom.uuid,
      expires_at: 5.minutes.from_now,
    )
  end

  def decode_result(token)
    IdentityStepUpCeremonyResult.decode(
      token,
      issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id("app"),
    )
  end

  test "a result that records a level reports it as a symbol" do
    assert_equal :aal2, decode_result(issue_result(aal: "aal2")).achieved_aal
  end

  test "a result that records no particular level reports nothing rather than the sentinel" do
    assert_nil decode_result(issue_result(aal: StepUpRequirement::NO_AAL)).achieved_aal
  end
end

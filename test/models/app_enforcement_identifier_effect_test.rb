# typed: false
# frozen_string_literal: true

require "test_helper"

class AppEnforcementIdentifierEffectTest < ActiveSupport::TestCase
  test "build helpers return nil when the identifier cannot be digested" do
    assert_nil AppEnforcementIdentifierEffect.build_for_email(value: "")
    assert_nil AppEnforcementIdentifierEffect.build_for_telephone(value: "")
    assert_nil AppEnforcementIdentifierEffect.build_for_google_subject(issuer: "", subject: "sub")
    assert_nil AppEnforcementIdentifierEffect.build_for_apple_subject(issuer: "https://appleid.apple.com", subject: "")
  end

  test "build helpers return an unsaved effect when the identifier is digestable" do
    email_effect = AppEnforcementIdentifierEffect.build_for_email(value: "coverage-effect@example.test")
    telephone_effect = AppEnforcementIdentifierEffect.build_for_telephone(value: "+819055511111")
    google_effect = AppEnforcementIdentifierEffect.build_for_google_subject(
      issuer: "https://accounts.google.com",
      subject: "google-subject-coverage",
    )
    apple_effect = AppEnforcementIdentifierEffect.build_for_apple_subject(
      issuer: "https://appleid.apple.com",
      subject: "apple-subject-coverage",
    )

    assert_equal "email", email_effect.identifier_kind
    assert_equal "telephone", telephone_effect.identifier_kind
    assert_equal "google_subject", google_effect.identifier_kind
    assert_equal "apple_subject", apple_effect.identifier_kind
    assert_predicate email_effect.lookup_digest, :present?
    assert_not email_effect.persisted?
  end

  test "rejects identifier effects on a method-only freeze case" do
    client = clients(:one)
    operator = operators(:one)
    enforcement_case = AppEnforcementCase.create!(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    effect = AppEnforcementIdentifierEffect.build_for_email(
      value: "coverage-freeze@example.test",
      enforcement_case: enforcement_case,
      effective_at: Time.current,
    )

    assert_not effect.valid?
    assert_includes effect.errors[:base], "Identifier Effect is only legal on permanent_ban or cooldown Cases"
  end

  test "in_force selects only open, currently effective, unexpired identifier effects" do
    enforcement_case = ban_case
    open_effect = create_effect(enforcement_case, "in-force-app@example.test", effective_at: 1.hour.ago)
    future = create_effect(enforcement_case, "future-app@example.test", effective_at: 1.hour.from_now)
    expired = create_effect(enforcement_case, "expired-app@example.test", effective_at: 2.hours.ago, expires_at: 1.hour.ago)
    ended = create_effect(enforcement_case, "ended-app@example.test", effective_at: 2.hours.ago, ended_at: 1.hour.ago)

    in_force = AppEnforcementIdentifierEffect.in_force

    assert_includes in_force, open_effect
    assert_not_includes in_force, future
    assert_not_includes in_force, expired
    assert_not_includes in_force, ended
  end

  private

  def ban_case
    AppEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: clients(:one).public_id,
      applied_by_operator_public_id: operators(:one).public_id,
    )
  end

  def create_effect(enforcement_case, value, **attrs)
    AppEnforcementIdentifierEffect.build_for_email(
      value: value,
      enforcement_case: enforcement_case,
      **attrs,
    ).tap(&:save!)
  end
end

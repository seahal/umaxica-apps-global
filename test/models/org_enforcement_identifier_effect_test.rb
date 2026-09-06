# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgEnforcementIdentifierEffectTest < ActiveSupport::TestCase
  test "build helpers return nil when the identifier cannot be digested" do
    assert_nil OrgEnforcementIdentifierEffect.build_for_email(value: "")
    assert_nil OrgEnforcementIdentifierEffect.build_for_telephone(value: "")
  end

  test "build helpers return an unsaved effect when the identifier is digestable" do
    email_effect = OrgEnforcementIdentifierEffect.build_for_email(value: "coverage-org@example.test")
    telephone_effect = OrgEnforcementIdentifierEffect.build_for_telephone(value: "+819055533333")

    assert_equal "email", email_effect.identifier_kind
    assert_equal "telephone", telephone_effect.identifier_kind
    assert_predicate email_effect.lookup_digest, :present?
  end

  test "rejects identifier effects on a temporary freeze case" do
    enforcement_case = OrgEnforcementCase.create!(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      principal_public_id: operators(:two).public_id,
      applied_by_operator_public_id: operators(:one).public_id,
    )
    effect = OrgEnforcementIdentifierEffect.build_for_email(
      value: "coverage-org-freeze@example.test",
      enforcement_case: enforcement_case,
      effective_at: Time.current,
    )

    assert_not effect.valid?
    assert_includes effect.errors[:base], "Identifier Effect is only legal on permanent_ban or cooldown Cases"
  end

  test "allows a principal effect without a case and rejects method protection cases" do
    effect_without_case = OrgEnforcementPrincipalEffect.new(
      principal_public_id: operators(:two).public_id,
      effective_at: Time.current,
    )
    method_protection_case = OrgEnforcementCase.new(kind: "method_protection")
    protected_effect = OrgEnforcementPrincipalEffect.new(
      enforcement_case: method_protection_case,
      principal_public_id: operators(:two).public_id,
      effective_at: Time.current,
    )

    effect_without_case.valid?
    assert_empty effect_without_case.errors[:base]
    assert_not protected_effect.valid?
    assert_includes protected_effect.errors[:base], "method_protection Cases may not carry a Principal Effect"
  end

  test "in_force selects only open, currently effective, unexpired identifier effects" do
    enforcement_case = cooldown_case
    open_effect = create_effect(enforcement_case, "in-force-org@example.test", effective_at: 1.hour.ago)
    future = create_effect(enforcement_case, "future-org@example.test", effective_at: 1.hour.from_now)
    expired = create_effect(
      enforcement_case, "expired-org@example.test", effective_at: 2.hours.ago,
                                                    expires_at: 1.hour.ago,
    )
    ended = create_effect(enforcement_case, "ended-org@example.test", effective_at: 2.hours.ago, ended_at: 1.hour.ago)

    in_force = OrgEnforcementIdentifierEffect.in_force

    assert_includes in_force, open_effect
    assert_not_includes in_force, future
    assert_not_includes in_force, expired
    assert_not_includes in_force, ended
  end

  private

  def cooldown_case
    OrgEnforcementCase.create!(
      kind: "cooldown",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "automatic",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "abuse",
      principal_public_id: operators(:two).public_id,
      applied_by_operator_public_id: operators(:one).public_id,
    )
  end

  def create_effect(enforcement_case, value, **attrs)
    OrgEnforcementIdentifierEffect.build_for_email(
      value: value,
      enforcement_case: enforcement_case,
      **attrs,
    ).tap(&:save!)
  end
end

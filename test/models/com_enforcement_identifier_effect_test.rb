# typed: false
# frozen_string_literal: true

require "test_helper"

class ComEnforcementIdentifierEffectTest < ActiveSupport::TestCase
  test "build helpers return nil when the identifier cannot be digested" do
    assert_nil ComEnforcementIdentifierEffect.build_for_email(value: "")
    assert_nil ComEnforcementIdentifierEffect.build_for_telephone(value: "")
  end

  test "build helpers return an unsaved effect when the identifier is digestable" do
    email_effect = ComEnforcementIdentifierEffect.build_for_email(value: "coverage-com@example.test")
    telephone_effect = ComEnforcementIdentifierEffect.build_for_telephone(value: "+819055522222")

    assert_equal "email", email_effect.identifier_kind
    assert_equal "telephone", telephone_effect.identifier_kind
    assert_predicate email_effect.lookup_digest, :present?
  end

  test "rejects identifier effects on a method-protection case" do
    visitor = visitors(:reserved_visitor)
    operator = operators(:one)
    enforcement_case = ComEnforcementCase.create!(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: visitor.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    effect = ComEnforcementIdentifierEffect.build_for_email(
      value: "coverage-com-freeze@example.test",
      enforcement_case: enforcement_case,
      effective_at: Time.current,
    )

    assert_not effect.valid?
    assert_includes effect.errors[:base], "Identifier Effect is only legal on permanent_ban or cooldown Cases"
  end

  test "in_force selects only open, currently effective, unexpired identifier effects" do
    enforcement_case = ban_case
    open_effect = create_effect(enforcement_case, "in-force-com@example.test", effective_at: 1.hour.ago)
    future = create_effect(enforcement_case, "future-com@example.test", effective_at: 1.hour.from_now)
    expired = create_effect(enforcement_case, "expired-com@example.test", effective_at: 2.hours.ago, expires_at: 1.hour.ago)
    ended = create_effect(enforcement_case, "ended-com@example.test", effective_at: 2.hours.ago, ended_at: 1.hour.ago)

    in_force = ComEnforcementIdentifierEffect.in_force

    assert_includes in_force, open_effect
    assert_not_includes in_force, future
    assert_not_includes in_force, expired
    assert_not_includes in_force, ended
  end

  private

  def ban_case
    ComEnforcementCase.create!(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: visitors(:reserved_visitor).public_id,
      applied_by_operator_public_id: operators(:one).public_id,
    )
  end

  def create_effect(enforcement_case, value, **attrs)
    ComEnforcementIdentifierEffect.build_for_email(
      value: value,
      enforcement_case: enforcement_case,
      **attrs,
    ).tap(&:save!)
  end
end

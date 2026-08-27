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
end

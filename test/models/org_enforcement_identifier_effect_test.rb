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
end

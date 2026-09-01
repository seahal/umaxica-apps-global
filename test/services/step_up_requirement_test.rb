# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StepUpRequirementTest < ActiveSupport::TestCase
  test "build from hash merges attributes" do
    requirement = StepUpRequirement.build({ scope: "profile", required_aal: "aal2" }, purpose: "login")

    assert_equal "profile", requirement.scope
    assert_equal :aal2, requirement.required_aal
    assert_equal "login", requirement.purpose
  end

  test "build from nil uses defaults with scope as positional" do
    requirement = StepUpRequirement.build(nil, scope: "profile")

    assert_equal "profile", requirement.scope
    assert_nil requirement.required_aal
    assert_predicate requirement, :step_up_required?
    assert_not_predicate requirement, :phishing_resistant_required?
  end

  test "normal step up keeps freshness separate from assurance" do
    requirement = StepUpRequirement.new(
      scope: "profile",
      required_aal: nil,
      phishing_resistant_required: false,
      allowed_methods: %i(passkey totp email_otp),
    )

    assert_predicate requirement, :step_up_required?
    assert_nil requirement.required_aal
    assert_not_predicate requirement, :aal_required?
    assert_not_predicate requirement, :phishing_resistant_required?
    assert requirement.method_allowed?(:email_otp)
  end

  test "high assurance conditions remain independently expressible" do
    requirement = StepUpRequirement.new(
      scope: "profile",
      required_aal: :aal2,
      phishing_resistant_required: true,
      allowed_methods: [:passkey],
    )

    assert_predicate requirement, :aal_required?
    assert_predicate requirement, :phishing_resistant_required?
    assert_equal :aal2, requirement.required_aal
  end
end

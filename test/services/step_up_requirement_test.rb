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
    assert_equal :aal2, requirement.required_aal
  end
end

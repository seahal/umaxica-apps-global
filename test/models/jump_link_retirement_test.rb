# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpLinkRetirementTest < ActiveSupport::TestCase
  test "legacy DB-backed jump link models are not available" do
    assert_not Object.const_defined?(:AppJumpLink)
    assert_not Object.const_defined?(:ComJumpLink)
    assert_not Object.const_defined?(:OrgJumpLink)
    assert_not Object.const_defined?(:JumpLinkable)
  end
end

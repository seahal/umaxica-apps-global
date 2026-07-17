# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgEntraIdentityResolutionTest < ActiveSupport::TestCase
  test "resolved value exposes the identity and operator" do
    identity = Object.new
    operator = Object.new

    resolution = OrgEntraIdentityResolution.resolved(identity: identity, operator: operator)

    assert_predicate resolution, :resolved?
    assert_not_predicate resolution, :rejected?
    assert_equal identity, resolution.identity
    assert_equal operator, resolution.operator
    assert_nil resolution.error
  end

  test "rejected value may retain the matched identity without an operator" do
    identity = Object.new

    resolution = OrgEntraIdentityResolution.rejected(error: "operator_not_found", identity: identity)

    assert_predicate resolution, :rejected?
    assert_not_predicate resolution, :resolved?
    assert_equal identity, resolution.identity
    assert_nil resolution.operator
    assert_equal "operator_not_found", resolution.error
  end
end

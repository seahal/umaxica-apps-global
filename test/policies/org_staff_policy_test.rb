# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgStaffPolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "denies nil actor" do
    assert_not OrgStaffPolicy.new(:org_staff, user: nil).index?
  end

  test "denies non operator actor" do
    client = Client.new

    assert_not OrgStaffPolicy.new(:org_staff, user: client).index?
  end

  test "denies operator without delegated staff area role" do
    operator = Operator.new

    assert_not OrgStaffPolicy.new(:org_staff, user: operator).index?
  end

  test "allows operator when delegated manager role permits view" do
    operator = Operator.new
    operator.define_singleton_method(:operator_or_manager?) { |organization:| organization.nil? }
    operator.define_singleton_method(:can_view?) { |organization:| organization.nil? }

    policy = OrgStaffPolicy.new(:org_staff, user: operator)

    assert_predicate policy, :index?
    assert_predicate policy, :show?
  end
end

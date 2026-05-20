# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceWritePolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "shared preference policies allow token-scoped updates without an actor" do
    assert_predicate AppPreferencePolicy.new(AppPreference.new, user: nil), :update?
    assert_predicate OrgPreferencePolicy.new(OrgPreference.new, user: nil), :update?
    assert_predicate ComPreferencePolicy.new(ComPreference.new, user: nil), :update?
  end

  test "client preference policy only allows the owning client" do
    owner = Client.new(id: 10)
    other = Client.new(id: 20)
    preference = ClientPreference.new(user_id: owner.id)

    assert_predicate ClientPreferencePolicy.new(preference, user: owner), :update?
    assert_not ClientPreferencePolicy.new(preference, user: other).update?
    assert_not ClientPreferencePolicy.new(preference, user: nil).update?
  end

  test "operator preference policy only allows the owning operator" do
    owner = Operator.new(id: 10)
    other = Operator.new(id: 20)
    preference = OperatorPreference.new(staff_id: owner.id)

    assert_predicate OperatorPreferencePolicy.new(preference, user: owner), :update?
    assert_not OperatorPreferencePolicy.new(preference, user: other).update?
    assert_not OperatorPreferencePolicy.new(preference, user: nil).update?
  end

  test "visitor preference policy only allows the owning visitor" do
    owner = Visitor.new(id: 10)
    other = Visitor.new(id: 20)
    preference = VisitorPreference.new(visitor_id: owner.id)

    assert_predicate VisitorPreferencePolicy.new(preference, user: owner), :update?
    assert_not VisitorPreferencePolicy.new(preference, user: other).update?
    assert_not VisitorPreferencePolicy.new(preference, user: nil).update?
  end
end

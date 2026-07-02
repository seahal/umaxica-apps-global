# typed: false
# frozen_string_literal: true

require "test_helper"

class ComVisitorPreferenceCurrentBehaviorTest < ActiveSupport::TestCase
  class ComVisitorPreferenceAdoptionProbe
    include PreferenceBase
    include PreferenceAdoption

    attr_accessor :preferences

    def controller_path
      "base/com/preferences"
    end

    def current_behavior_adoptable?
      send(:adoptable_preference_class?)
    end

    def adopt!(resource)
      send(:adopt_preference_for!, resource)
    end
  end

  test "Com Visitor is included in adoptable preference classes alongside App/Client and Org/Operator" do
    assert_predicate ComVisitorPreferenceAdoptionProbe.new, :current_behavior_adoptable?
  end

  test "Com login-time adoption creates and syncs the visitor local preference mirror" do
    visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
      mfa_level_id: VisitorMfaLevel::NOTHING,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
      discarded_at: 20.years.from_now,
      purged_at: 20.years.from_now,
    )
    shared = com_preferences(:one)

    probe = ComVisitorPreferenceAdoptionProbe.new
    probe.preferences = shared

    assert_nil visitor.reload.visitor_preference

    probe.adopt!(visitor)

    mirror = visitor.reload.visitor_preference

    assert_not_nil mirror, "expected Com adoption to create the VisitorPreference mirror"
    assert_not_nil mirror.updated_at
  end
end

# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OrgPreferenceChronicleEventTest < ActiveSupport::TestCase
  fixtures :org_preference_chronicle_events

  test "accepts integer ids" do
    record = OrgPreferenceChronicleEvent.new(id: 9)

    assert_predicate record, :valid?
  end

  test "includes all default ids" do
    ids = OrgPreferenceChronicleEvent.pluck(:id)

    assert_empty(OrgPreferenceChronicleEvent::DEFAULTS - ids)
  end
end

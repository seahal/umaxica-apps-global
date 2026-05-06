# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_contact_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
require "test_helper"

class AppContactChronicleEventTest < ActiveSupport::TestCase
  test "has correct constants" do
    assert_equal 0, AppContactChronicleEvent::NOTHING
    assert_equal 1, AppContactChronicleEvent::LEGACY_NOTHING
    assert_equal 2, AppContactChronicleEvent::CREATED
    assert_equal 3, AppContactChronicleEvent::UPDATED
    assert_equal 4, AppContactChronicleEvent::DELETED
  end

  test "can load nothing status from db" do
    status = AppContactChronicleEvent.find(AppContactChronicleEvent::NOTHING)

    assert_equal 0, status.id
  end

  test "ensure_defaults! does nothing when defaults exist" do
    assert_no_difference "AppContactChronicleEvent.count" do
      AppContactChronicleEvent.ensure_defaults!
    end
  end
end

# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_chronicle_events
# Database name: chronicle
#
#  id :bigint           not null, primary key
#

require "test_helper"

class StaffChronicleEventTest < ActiveSupport::TestCase
  setup do
    @model_class = StaffChronicleEvent
    @valid_id = StaffChronicleEvent::LOGGED_IN
    @subject = @model_class.new(id: @valid_id)
  end

  test "accepts integer ids" do
    record = StaffChronicleEvent.new(id: 9)

    assert_predicate record, :valid?
  end

  test "all constants are defined with correct values" do
    assert_equal 1, StaffChronicleEvent::LOGIN_SUCCESS
    assert_equal 2, StaffChronicleEvent::AUTHORIZATION_FAILED
    assert_equal 3, StaffChronicleEvent::LOGGED_IN
    assert_equal 4, StaffChronicleEvent::LOGGED_OUT
    assert_equal 5, StaffChronicleEvent::LOGIN_FAILED
    assert_equal 6, StaffChronicleEvent::TOKEN_REFRESHED
    assert_equal 7, StaffChronicleEvent::NOTHING
    assert_equal 8, StaffChronicleEvent::STAFF_SECRET_CREATED
    assert_equal 9, StaffChronicleEvent::STAFF_SECRET_REMOVED
    assert_equal 10, StaffChronicleEvent::STAFF_SECRET_UPDATED
  end

  test "has_many association with staff_chronicles" do
    association = StaffChronicleEvent.reflect_on_association(:staff_chronicles)

    assert_equal :has_many, association.macro
    assert_equal :destroy, association.options[:dependent]
    assert_equal :event_id, association.options[:foreign_key]
  end
end

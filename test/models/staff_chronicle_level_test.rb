# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#

require "test_helper"

class StaffChronicleLevelTest < ActiveSupport::TestCase
  fixtures :staffs, :staff_statuses, :staff_chronicle_levels, :staff_chronicle_events

  test "restrict_with_error on destroy when audits exist" do
    level = StaffChronicleLevel.find(StaffChronicleLevel::NOTHING)
    StaffChronicle.create!(
      staff: Staff.find_by!(public_id: "BCDE2345FGHJ67KM"),
      staff_chronicle_event: StaffChronicleEvent.find(StaffChronicleEvent::LOGIN_SUCCESS),
      staff_chronicle_level: level,
      timestamp: Time.current,
    )

    assert_no_difference "StaffChronicleLevel.count" do
      assert_not level.destroy
    end
    assert_not_empty level.errors[:base]
    assert_equal "staff chroniclesが存在しているので削除できません", level.errors[:base].first
  end

  test "can destroy when no audits exist" do
    level = StaffChronicleLevel.create!(id: 2)

    assert_difference "StaffChronicleLevel.count", -1 do
      assert level.destroy
    end
  end

  test "accepts integer ids" do
    record = StaffChronicleLevel.new(id: 3)

    assert_predicate record, :valid?
  end

  test "NOTHING constant is defined" do
    assert_equal 1, StaffChronicleLevel::NOTHING
  end

  test "has_many association with staff_chronicles" do
    association = StaffChronicleLevel.reflect_on_association(:staff_chronicles)

    assert_equal :has_many, association.macro
    assert_equal :restrict_with_error, association.options[:dependent]
    assert_equal :level_id, association.options[:foreign_key]
  end
end

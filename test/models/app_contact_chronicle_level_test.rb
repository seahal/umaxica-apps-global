# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_contact_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
require "test_helper"

class AppContactChronicleLevelTest < ActiveSupport::TestCase
  test "has correct constants" do
    assert_equal 0, AppContactChronicleLevel::NOTHING
    assert_equal 1, AppContactChronicleLevel::LEGACY_NOTHING
    assert_equal 2, AppContactChronicleLevel::DEBUG
    assert_equal 3, AppContactChronicleLevel::INFO
    assert_equal 4, AppContactChronicleLevel::WARN
    assert_equal 5, AppContactChronicleLevel::ERROR
  end

  test "can load nothing status from db" do
    status = AppContactChronicleLevel.find(AppContactChronicleLevel::NOTHING)

    assert_equal 0, status.id
  end

  test "ensure_defaults! does nothing when defaults exist" do
    assert_no_difference "AppContactChronicleLevel.count" do
      AppContactChronicleLevel.ensure_defaults!
    end
  end
end

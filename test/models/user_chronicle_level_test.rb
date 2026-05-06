# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#

require "test_helper"

class UserChronicleLevelTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "accepts integer ids" do
    record = UserChronicleLevel.new(id: 9)

    assert_predicate record, :valid?
  end

  test "constants are defined" do
    assert_equal 1, UserChronicleLevel::DEBUG
    assert_equal 2, UserChronicleLevel::ERROR
    assert_equal 3, UserChronicleLevel::INFO
    assert_equal 4, UserChronicleLevel::NOTHING
    assert_equal 5, UserChronicleLevel::WARN
  end

  test "ensure_defaults! creates records" do
    UserChronicleLevel.delete_all
    assert_difference("UserChronicleLevel.count", 5) do
      UserChronicleLevel.ensure_defaults!
    end
    assert UserChronicleLevel.exists?(id: UserChronicleLevel::DEBUG)
  end

  test "returns all default records" do
    UserChronicleLevel.ensure_defaults!
    ids = UserChronicleLevel.pluck(:id)

    assert_equal UserChronicleLevel::DEFAULTS.sort, ids.sort
  end
end

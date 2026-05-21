# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#

require "test_helper"

class ClientChronicleLevelTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "accepts integer ids" do
    record = ClientChronicleLevel.new(id: 9)

    assert_predicate record, :valid?
  end

  test "constants are defined" do
    assert_equal 1, ClientChronicleLevel::DEBUG
    assert_equal 2, ClientChronicleLevel::ERROR
    assert_equal 3, ClientChronicleLevel::INFO
    assert_equal 4, ClientChronicleLevel::NOTHING
    assert_equal 5, ClientChronicleLevel::WARN
  end

  test "ensure_defaults! creates records" do
    ClientChronicleLevel.delete_all
    assert_difference("ClientChronicleLevel.count", 5) do
      ClientChronicleLevel.ensure_defaults!
    end
    assert ClientChronicleLevel.exists?(id: ClientChronicleLevel::DEBUG)
  end

  test "returns all default records" do
    ClientChronicleLevel.ensure_defaults!
    ids = ClientChronicleLevel.pluck(:id)

    assert_equal ClientChronicleLevel::DEFAULTS.sort, ids.sort
  end
end

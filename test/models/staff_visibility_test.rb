# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_visibilities
# Database name: operator
#
#  id :bigint           not null, primary key
#
require "test_helper"

class OperatorVisibilityTest < ActiveSupport::TestCase
  fixtures :staff_visibilities, :staffs

  test "has expected fixed ids" do
    assert OperatorVisibility.exists?(id: OperatorVisibility::NOBODY)
    assert OperatorVisibility.exists?(id: OperatorVisibility::USER)
    assert OperatorVisibility.exists?(id: OperatorVisibility::STAFF)
    assert OperatorVisibility.exists?(id: OperatorVisibility::BOTH)
  end

  test "has many staffs association" do
    assoc = OperatorVisibility.reflect_on_association(:staffs)

    assert_not_nil assoc
    assert_equal :has_many, assoc.macro
  end
end

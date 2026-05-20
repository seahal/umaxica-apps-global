# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorWithdrawalTest < ActiveSupport::TestCase
  test "operator can be marked withdrawn and permanently destroyed" do
    staff = Operator.create!

    staff.update!(withdrawn_at: 31.days.ago)

    assert_predicate staff, :withdrawn?

    staff_id = staff.id
    staff.destroy

    assert_nil Operator.find_by(id: staff_id), "Operator should be removed after destroy"
  end
end

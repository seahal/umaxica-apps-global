# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_user_occurrences
# Database name: occurrence
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  staff_occurrence_id :bigint           not null
#  user_occurrence_id  :bigint           not null
#
# Indexes
#
#  idx_staff_user_occ_on_ids                           (staff_occurrence_id,user_occurrence_id) UNIQUE
#  index_staff_user_occurrences_on_user_occurrence_id  (user_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_occurrence_id => staff_occurrences.id)
#  fk_rails_...  (user_occurrence_id => user_occurrences.id)
#

require "test_helper"

class OperatorUserOccurrenceTest < ActiveSupport::TestCase
  test "associations" do
    staff = OperatorOccurrence.create!(body: "staff-001")
    user = UserOccurrence.create!(body: "user-001")
    record = OperatorUserOccurrence.new(
      staff_occurrence: staff,
      user_occurrence: user,
    )

    assert record.save!
    assert_equal staff, record.staff_occurrence
    assert_equal user, record.user_occurrence
  end

  test "uniqueness validation" do
    staff = OperatorOccurrence.create!(body: "staff-002")
    user = UserOccurrence.create!(body: "user-002")
    OperatorUserOccurrence.create!(staff_occurrence: staff, user_occurrence: user)
    duplicate = OperatorUserOccurrence.new(staff_occurrence: staff, user_occurrence: user)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:staff_occurrence_id]
  end
end

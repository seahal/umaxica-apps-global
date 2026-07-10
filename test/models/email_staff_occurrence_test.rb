# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: email_staff_occurrences
# Database name: occurrence
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  email_occurrence_id :bigint           not null
#  staff_occurrence_id :bigint           not null
#
# Indexes
#
#  idx_email_staff_occ_on_ids                            (email_occurrence_id,staff_occurrence_id) UNIQUE
#  index_email_staff_occurrences_on_staff_occurrence_id  (staff_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (email_occurrence_id => email_occurrences.id)
#  fk_rails_...  (staff_occurrence_id => staff_occurrences.id)
#

require "test_helper"

class EmailOperatorOccurrenceTest < ActiveSupport::TestCase
  test "associations" do
    email = EmailOccurrence.create!(body: "test@example.com")
    staff = OperatorOccurrence.create!(body: "staff-001")
    record = EmailOperatorOccurrence.new(
      email_occurrence: email,
      staff_occurrence: staff,
    )

    assert record.save!
    assert_equal email, record.email_occurrence
    assert_equal staff, record.staff_occurrence
  end

  test "uniqueness validation" do
    email = EmailOccurrence.create!(body: "test2@example.com")
    staff = OperatorOccurrence.create!(body: "staff-002")
    EmailOperatorOccurrence.create!(email_occurrence: email, staff_occurrence: staff)
    duplicate = EmailOperatorOccurrence.new(email_occurrence: email, staff_occurrence: staff)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:email_occurrence_id]
  end
end

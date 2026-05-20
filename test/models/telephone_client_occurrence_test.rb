# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: telephone_user_occurrences
# Database name: occurrence
#
#  id                      :bigint           not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  telephone_occurrence_id :bigint           not null
#  user_occurrence_id      :bigint           not null
#
# Indexes
#
#  idx_telephone_user_occ_on_ids                           (telephone_occurrence_id,user_occurrence_id) UNIQUE
#  index_telephone_user_occurrences_on_user_occurrence_id  (user_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (telephone_occurrence_id => telephone_occurrences.id)
#  fk_rails_...  (user_occurrence_id => user_occurrences.id)
#

require "test_helper"

class TelephoneClientOccurrenceTest < ActiveSupport::TestCase
  fixtures :telephone_occurrences

  test "associations" do
    user = ClientOccurrence.create!(body: "user-001")
    record = TelephoneClientOccurrence.new(
      telephone_occurrence: telephone_occurrences(:one),
      user_occurrence: user,
    )

    assert record.save!
    assert_equal telephone_occurrences(:one), record.telephone_occurrence
    assert_equal user, record.user_occurrence
  end

  test "uniqueness validation" do
    user = ClientOccurrence.create!(body: "user-002")
    TelephoneClientOccurrence.create!(
      telephone_occurrence: telephone_occurrences(:one),
      user_occurrence: user,
    )
    duplicate = TelephoneClientOccurrence.new(
      telephone_occurrence: telephone_occurrences(:one),
      user_occurrence: user,
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:telephone_occurrence_id]
  end
end

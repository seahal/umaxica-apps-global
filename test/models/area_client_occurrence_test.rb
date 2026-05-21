# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: area_client_occurrences
# Database name: occurrence
#
#  id                 :bigint           not null, primary key
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  area_occurrence_id :bigint           not null
#  user_occurrence_id :bigint           not null
#
# Indexes
#
#  idx_area_user_occ_on_ids                             (area_occurrence_id,user_occurrence_id) UNIQUE
#  index_area_client_occurrences_on_user_occurrence_id  (user_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (area_occurrence_id => area_occurrences.id)
#  fk_rails_...  (user_occurrence_id => client_occurrences.id)
#

require "test_helper"

class AreaClientOccurrenceTest < ActiveSupport::TestCase
  fixtures :area_occurrences

  test "associations" do
    area = area_occurrences(:one)
    user = ClientOccurrence.create!(body: "user-001")
    record = AreaClientOccurrence.new(
      area_occurrence: area,
      user_occurrence: user,
    )

    assert record.save!
    assert_equal area, record.area_occurrence
    assert_equal user, record.user_occurrence
  end

  test "uniqueness validation" do
    area = area_occurrences(:one)
    user = ClientOccurrence.create!(body: "user-002")
    AreaClientOccurrence.create!(area_occurrence: area, user_occurrence: user)
    duplicate = AreaClientOccurrence.new(area_occurrence: area, user_occurrence: user)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:area_occurrence_id]
  end
end

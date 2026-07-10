# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: email_client_occurrences
# Database name: occurrence
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  email_occurrence_id :bigint           not null
#  user_occurrence_id  :bigint           not null
#
# Indexes
#
#  idx_email_user_occ_on_ids                             (email_occurrence_id,user_occurrence_id) UNIQUE
#  index_email_client_occurrences_on_user_occurrence_id  (user_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (email_occurrence_id => email_occurrences.id)
#  fk_rails_...  (user_occurrence_id => client_occurrences.id)
#

require "test_helper"

class EmailClientOccurrenceTest < ActiveSupport::TestCase
  test "associations" do
    email = EmailOccurrence.create!(body: "test@example.com")
    user = ClientOccurrence.create!(body: "user-001")
    record = EmailClientOccurrence.new(
      email_occurrence: email,
      user_occurrence: user,
    )

    assert record.save!
    assert_equal email, record.email_occurrence
    assert_equal user, record.user_occurrence
  end

  test "uniqueness validation" do
    email = EmailOccurrence.create!(body: "test2@example.com")
    user = ClientOccurrence.create!(body: "user-002")
    EmailClientOccurrence.create!(email_occurrence: email, user_occurrence: user)
    duplicate = EmailClientOccurrence.new(email_occurrence: email, user_occurrence: user)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:email_occurrence_id]
  end
end

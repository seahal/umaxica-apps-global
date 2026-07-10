# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: email_visitor_occurrences
# Database name: occurrence
#
#  id                    :bigint           not null, primary key
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  email_occurrence_id   :bigint           not null
#  visitor_occurrence_id :bigint           not null
#
# Indexes
#
#  idx_email_visitor_occ_on_ids                              (email_occurrence_id,visitor_occurrence_id) UNIQUE
#  index_email_visitor_occurrences_on_visitor_occurrence_id  (visitor_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (email_occurrence_id => email_occurrences.id)
#  fk_rails_...  (visitor_occurrence_id => visitor_occurrences.id)
#
require "test_helper"

class EmailVisitorOccurrenceTest < ActiveSupport::TestCase
  setup do
    VisitorOccurrenceStatus.ensure_defaults!
  end

  test "associations" do
    email = EmailOccurrence.create!(body: "visitor@example.com")
    visitor = VisitorOccurrence.create!(body: "visitor-email-001")
    record = EmailVisitorOccurrence.new(
      email_occurrence: email,
      visitor_occurrence: visitor,
    )

    assert record.save!
    assert_equal email, record.email_occurrence
    assert_equal visitor, record.visitor_occurrence
  end

  test "uniqueness validation" do
    email = EmailOccurrence.create!(body: "visitor2@example.com")
    visitor = VisitorOccurrence.create!(body: "visitor-email-002")
    EmailVisitorOccurrence.create!(email_occurrence: email, visitor_occurrence: visitor)
    duplicate = EmailVisitorOccurrence.new(email_occurrence: email, visitor_occurrence: visitor)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:email_occurrence_id]
  end
end

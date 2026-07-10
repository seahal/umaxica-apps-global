# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: ip_visitor_occurrences
# Database name: occurrence
#
#  id                    :bigint           not null, primary key
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  ip_occurrence_id      :bigint           not null
#  visitor_occurrence_id :bigint           not null
#
# Indexes
#
#  idx_ip_visitor_occ_on_ids                              (ip_occurrence_id,visitor_occurrence_id) UNIQUE
#  index_ip_visitor_occurrences_on_visitor_occurrence_id  (visitor_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (ip_occurrence_id => ip_occurrences.id)
#  fk_rails_...  (visitor_occurrence_id => visitor_occurrences.id)
#
require "test_helper"

class IpVisitorOccurrenceTest < ActiveSupport::TestCase
  setup do
    VisitorOccurrenceStatus.ensure_defaults!
  end

  test "associations" do
    ip = IpOccurrence.create!(body: "203.0.113.10")
    visitor = VisitorOccurrence.create!(body: "visitor-ip-001")
    record = IpVisitorOccurrence.new(
      ip_occurrence: ip,
      visitor_occurrence: visitor,
    )

    assert record.save!
    assert_equal ip, record.ip_occurrence
    assert_equal visitor, record.visitor_occurrence
  end

  test "uniqueness validation" do
    ip = IpOccurrence.create!(body: "203.0.113.11")
    visitor = VisitorOccurrence.create!(body: "visitor-ip-002")
    IpVisitorOccurrence.create!(ip_occurrence: ip, visitor_occurrence: visitor)
    duplicate = IpVisitorOccurrence.new(ip_occurrence: ip, visitor_occurrence: visitor)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:ip_occurrence_id]
  end
end

# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: domain_staff_occurrences
# Database name: occurrence
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  domain_occurrence_id :bigint           not null
#  staff_occurrence_id  :bigint           not null
#
# Indexes
#
#  idx_domain_staff_occ_on_ids                            (domain_occurrence_id,staff_occurrence_id) UNIQUE
#  index_domain_staff_occurrences_on_staff_occurrence_id  (staff_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (domain_occurrence_id => domain_occurrences.id)
#  fk_rails_...  (staff_occurrence_id => staff_occurrences.id)
#

require "test_helper"

class DomainOperatorOccurrenceTest < ActiveSupport::TestCase
  fixtures :domain_occurrences

  test "associations" do
    domain = domain_occurrences(:one)
    staff = OperatorOccurrence.create!(body: "staff-001")
    record = DomainOperatorOccurrence.new(
      domain_occurrence: domain,
      staff_occurrence: staff,
    )

    assert record.save!
    assert_equal domain, record.domain_occurrence
    assert_equal staff, record.staff_occurrence
  end

  test "uniqueness validation" do
    domain = domain_occurrences(:one)
    staff = OperatorOccurrence.create!(body: "staff-002")
    DomainOperatorOccurrence.create!(domain_occurrence: domain, staff_occurrence: staff)
    duplicate = DomainOperatorOccurrence.new(domain_occurrence: domain, staff_occurrence: staff)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:domain_occurrence_id]
  end
end

# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: domain_user_occurrences
# Database name: occurrence
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  domain_occurrence_id :bigint           not null
#  user_occurrence_id   :bigint           not null
#
# Indexes
#
#  idx_domain_user_occ_on_ids                           (domain_occurrence_id,user_occurrence_id) UNIQUE
#  index_domain_user_occurrences_on_user_occurrence_id  (user_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (domain_occurrence_id => domain_occurrences.id)
#  fk_rails_...  (user_occurrence_id => user_occurrences.id)
#

require "test_helper"

class DomainClientOccurrenceTest < ActiveSupport::TestCase
  fixtures :domain_occurrences

  test "associations" do
    domain = domain_occurrences(:one)
    user = ClientOccurrence.create!(body: "user-001")
    record = DomainClientOccurrence.new(
      domain_occurrence: domain,
      user_occurrence: user,
    )

    assert record.save!
    assert_equal domain, record.domain_occurrence
    assert_equal user, record.user_occurrence
  end

  test "uniqueness validation" do
    domain = domain_occurrences(:one)
    user = ClientOccurrence.create!(body: "user-002")
    DomainClientOccurrence.create!(domain_occurrence: domain, user_occurrence: user)
    duplicate = DomainClientOccurrence.new(domain_occurrence: domain, user_occurrence: user)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:domain_occurrence_id]
  end
end

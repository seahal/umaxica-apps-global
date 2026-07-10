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
class EmailVisitorOccurrence < OccurrenceRecord
  belongs_to :email_occurrence, inverse_of: :email_visitor_occurrences
  belongs_to :visitor_occurrence, inverse_of: :email_visitor_occurrences

  validates :email_occurrence_id, uniqueness: { scope: :visitor_occurrence_id }
end

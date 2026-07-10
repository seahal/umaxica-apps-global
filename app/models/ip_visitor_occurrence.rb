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
class IpVisitorOccurrence < OccurrenceRecord
  belongs_to :ip_occurrence, inverse_of: :ip_visitor_occurrences
  belongs_to :visitor_occurrence, inverse_of: :ip_visitor_occurrences

  validates :ip_occurrence_id, uniqueness: { scope: :visitor_occurrence_id }
end

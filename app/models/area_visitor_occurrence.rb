# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: area_visitor_occurrences
# Database name: occurrence
#
#  id                    :bigint           not null, primary key
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  area_occurrence_id    :bigint           not null
#  visitor_occurrence_id :bigint           not null
#
# Indexes
#
#  idx_area_visitor_occ_on_ids                              (area_occurrence_id,visitor_occurrence_id) UNIQUE
#  index_area_visitor_occurrences_on_visitor_occurrence_id  (visitor_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (area_occurrence_id => area_occurrences.id)
#  fk_rails_...  (visitor_occurrence_id => visitor_occurrences.id)
#
class AreaVisitorOccurrence < OccurrenceRecord
  belongs_to :area_occurrence, inverse_of: :area_visitor_occurrences
  belongs_to :visitor_occurrence, inverse_of: :area_visitor_occurrences

  validates :area_occurrence_id, uniqueness: { scope: :visitor_occurrence_id }
end

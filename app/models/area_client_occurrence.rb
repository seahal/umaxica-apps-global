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

class AreaClientOccurrence < OccurrenceRecord
  belongs_to :area_occurrence, inverse_of: :area_user_occurrences
  belongs_to :user_occurrence, class_name: "ClientOccurrence"

  validates :area_occurrence_id, uniqueness: { scope: :user_occurrence_id }
end

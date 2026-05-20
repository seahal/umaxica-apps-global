# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_zip_occurrences
# Database name: occurrence
#
#  id                 :bigint           not null, primary key
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  user_occurrence_id :bigint           not null
#  zip_occurrence_id  :bigint           not null
#
# Indexes
#
#  idx_user_zip_occ_on_ids                          (user_occurrence_id,zip_occurrence_id) UNIQUE
#  index_user_zip_occurrences_on_zip_occurrence_id  (zip_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_occurrence_id => user_occurrences.id)
#  fk_rails_...  (zip_occurrence_id => zip_occurrences.id)
#

class ClientZipOccurrence < OccurrenceRecord
  self.table_name = "user_zip_occurrences"
  belongs_to :user_occurrence, class_name: "ClientOccurrence", inverse_of: :client_zip_occurrences
  belongs_to :zip_occurrence, inverse_of: :client_zip_occurrences

  validates :user_occurrence_id, uniqueness: { scope: :zip_occurrence_id }
end

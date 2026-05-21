# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: domain_client_occurrences
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
#  idx_domain_user_occ_on_ids                             (domain_occurrence_id,user_occurrence_id) UNIQUE
#  index_domain_client_occurrences_on_user_occurrence_id  (user_occurrence_id)
#
# Foreign Keys
#
#  fk_rails_...  (domain_occurrence_id => domain_occurrences.id)
#  fk_rails_...  (user_occurrence_id => client_occurrences.id)
#

class DomainClientOccurrence < OccurrenceRecord
  belongs_to :domain_occurrence, inverse_of: :domain_user_occurrences
  belongs_to :user_occurrence, class_name: "ClientOccurrence"

  validates :domain_occurrence_id, uniqueness: { scope: :user_occurrence_id }
end

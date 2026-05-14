# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_personnels
# Database name: personnel
#
#  id                    :bigint           not null, primary key
#  audience              :string           not null
#  issuer                :string           not null
#  last_authenticated_at :datetime
#  lock_version          :integer          default(0), not null
#  subject               :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  public_id             :string           default(""), not null
#  source_record_id      :bigint           not null
#  status_id             :bigint           default(0), not null
#
# Indexes
#
#  index_staff_personnels_on_issuer_and_subject_and_audience  (issuer,subject,audience) UNIQUE
#  index_staff_personnels_on_public_id                        (public_id) UNIQUE
#  index_staff_personnels_on_source_record_id                 (source_record_id) UNIQUE
#  index_staff_personnels_on_status_id                        (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => staff_personnel_statuses.id)
#
class OperatorPersonnel < PersonnelRecord
  self.table_name = "staff_personnels"
  include ::PublicId

  belongs_to :staff_personnel_status, class_name: "OperatorPersonnelStatus", foreign_key: :status_id,
                                      inverse_of: :staff_personnels

  validates :issuer, :subject, :audience, :source_record_id, presence: true
  validates :public_id, uniqueness: true
  validates :source_record_id, uniqueness: true
  validates :subject, uniqueness: { scope: %i(issuer audience) }
end

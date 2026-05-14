# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_residents
# Database name: resident
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
#  index_user_residents_on_issuer_and_subject_and_audience  (issuer,subject,audience) UNIQUE
#  index_user_residents_on_public_id                        (public_id) UNIQUE
#  index_user_residents_on_source_record_id                 (source_record_id) UNIQUE
#  index_user_residents_on_status_id                        (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => user_resident_statuses.id)
#
class UserResident < ResidentRecord
  include ::PublicId

  belongs_to :user_resident_status,
             foreign_key: :status_id,
             inverse_of: :user_residents

  validates :issuer, :subject, :audience, :source_record_id, presence: true
  validates :public_id, uniqueness: true
  validates :source_record_id, uniqueness: true
  validates :subject, uniqueness: { scope: %i(issuer audience) }
end

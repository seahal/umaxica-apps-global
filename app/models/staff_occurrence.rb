# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_occurrences
# Database name: occurrence
#
#  id         :bigint           not null, primary key
#  body       :string           default(""), not null
#  context    :jsonb            not null
#  event_type :string           default(""), not null
#  lapses_at  :datetime         default(Infinity), not null
#  memo       :string           default(""), not null
#  purge_at   :datetime         default(Infinity), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string(21)       default(""), not null
#  status_id  :bigint           default(1), not null
#
# Indexes
#
#  index_staff_occurrences_on_body                       (body) UNIQUE
#  index_staff_occurrences_on_event_type_and_created_at  (event_type,created_at)
#  index_staff_occurrences_on_public_id                  (public_id) UNIQUE
#  index_staff_occurrences_on_purge_at                   (purge_at)
#  index_staff_occurrences_on_status_id_and_created_at   (status_id,created_at)
#
# Foreign Keys
#
#  fk_staff_occurrences_on_status_id  (status_id => staff_occurrence_statuses.id)
#

class StaffOccurrence < OccurrenceRecord
  include Retainable
  include PublicId
  include Occurrence

  ACTIVE_STATUS_ID = 1
  EXPIRED_STATUS_ID = 2

  attribute :status_id, default: StaffOccurrenceStatus::NOTHING

  belongs_to :staff_occurrence_status, foreign_key: :status_id, optional: true, inverse_of: :staff_occurrences
  has_many :area_staff_occurrences, dependent: :destroy, inverse_of: :staff_occurrence
  has_many :area_occurrences, through: :area_staff_occurrences
  has_many :domain_staff_occurrences, dependent: :destroy, inverse_of: :staff_occurrence
  has_many :domain_occurrences, through: :domain_staff_occurrences
  has_many :email_staff_occurrences, dependent: :destroy, inverse_of: :staff_occurrence
  has_many :email_occurrences, through: :email_staff_occurrences
  has_many :ip_staff_occurrences, dependent: :destroy, inverse_of: :staff_occurrence
  has_many :ip_occurrences, through: :ip_staff_occurrences
  has_many :staff_telephone_occurrences, dependent: :destroy, inverse_of: :staff_occurrence
  has_many :telephone_occurrences, through: :staff_telephone_occurrences
  has_many :staff_user_occurrences, dependent: :destroy, inverse_of: :staff_occurrence
  has_many :user_occurrences, through: :staff_user_occurrences
  has_many :staff_zip_occurrences, dependent: :destroy, inverse_of: :staff_occurrence
  has_many :zip_occurrences, through: :staff_zip_occurrences

  scope :active, -> { where(status_id: ACTIVE_STATUS_ID) }
  scope :expired, -> { where(status_id: EXPIRED_STATUS_ID) }

  validates :body, length: { maximum: 36 }
  validates :status_id, numericality: { only_integer: true }
  validates :event_type, length: { maximum: 255 }, allow_nil: true
end

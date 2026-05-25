# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_telephones
# Database name: org_principal
#
#  id                                 :bigint           not null, primary key
#  locked_at                          :datetime
#  number                             :string           not null
#  number_digest                      :string
#  otp_attempts_count                 :integer          default(0), not null
#  otp_counter                        :text             not null
#  otp_expires_at                     :datetime
#  otp_private_key                    :string           not null
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  staff_id                           :bigint           not null
#  staff_identity_telephone_status_id :bigint           default(6), not null
#
# Indexes
#
#  idx_on_staff_identity_telephone_status_id_6c01767c57  (staff_identity_telephone_status_id)
#  index_operator_telephones_on_number_digest            (number_digest) UNIQUE WHERE (number_digest IS NOT NULL)
#  index_operator_telephones_on_staff_id                 (staff_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (staff_identity_telephone_status_id => operator_telephone_statuses.id)
#

class OperatorTelephone < OrgPrincipalRecord
  alias_attribute :staff_telephone_status_id, :staff_identity_telephone_status_id
  include Telephone

  self.filter_attributes += %w(number)

  MAX_TELEPHONES_PER_STAFF = 4
  attribute :staff_identity_telephone_status_id, default: OperatorTelephoneStatus::UNVERIFIED

  belongs_to :staff_telephone_status, class_name: "OperatorTelephoneStatus",
                                      foreign_key: :staff_identity_telephone_status_id,
                                      inverse_of: :staff_telephones
  belongs_to :staff, class_name: "Operator"

  # Note: :number validation is now handled by Telephone concern (E.164 normalization)
  validates :number, presence: true
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :otp_counter, presence: true
  validates :otp_private_key, presence: true, length: { maximum: 255 }
  validates :staff_identity_telephone_status_id, numericality: { only_integer: true }
  validates :number_digest, blind_index_uniqueness: { error_attribute: :number }, allow_blank: true
  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :staff,
                 association: :staff_telephones,
                 foreign_key: :staff_id,
                 limit: :MAX_TELEPHONES_PER_STAFF,
                 record_name: "telephones",
                 owner_name: "staff"

  after_initialize do
    self.number ||= ""
  end

  # Note: :number encryption is handled by Telephone concern

  private
end

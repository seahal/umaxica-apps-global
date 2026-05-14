# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_telephones
# Database name: principal
#
#  id                                :bigint           not null, primary key
#  locked_at                         :datetime         default(-Infinity), not null
#  number                            :string           default(""), not null
#  number_digest                     :string
#  otp_attempts_count                :integer          default(0), not null
#  otp_counter                       :text             default(""), not null
#  otp_expires_at                    :datetime         default(-Infinity), not null
#  otp_private_key                   :string           default(""), not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  public_id                         :string(21)       not null
#  user_id                           :bigint           not null
#  user_identity_telephone_status_id :bigint           default(2), not null
#
# Indexes
#
#  index_user_telephones_on_lower_number                       (lower((number)::text)) UNIQUE
#  index_user_telephones_on_number_digest                      (number_digest) UNIQUE WHERE (number_digest IS NOT NULL)
#  index_user_telephones_on_public_id                          (public_id) UNIQUE
#  index_user_telephones_on_user_id                            (user_id)
#  index_user_telephones_on_user_identity_telephone_status_id  (user_identity_telephone_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (user_identity_telephone_status_id => user_telephone_statuses.id)
#

class UserTelephone < PrincipalRecord
  self.filter_attributes += %w(number)

  MAX_TELEPHONES_PER_USER = 4
  alias_attribute :user_telephone_status_id, :user_identity_telephone_status_id
  include Telephone
  include Turnstile
  include PublicId

  def to_param
    public_id
  end

  attribute :user_identity_telephone_status_id, default: UserTelephoneStatus::UNVERIFIED

  belongs_to :user_telephone_status, optional: true, inverse_of: :user_telephones,
                                     foreign_key: :user_identity_telephone_status_id
  belongs_to :user, inverse_of: :user_telephones

  # Note: :number validation is now handled by Telephone concern (E.164 normalization)
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :otp_counter, presence: true
  validates :otp_private_key, presence: true, length: { maximum: 255 }
  validates :user_identity_telephone_status_id, numericality: { only_integer: true }
  validate :ensure_unique_number_digest
  validate :enforce_user_telephone_limit, on: :create

  after_initialize do
    self.number ||= ""
  end

  # Note: :number encryption is handled by Telephone concern

  private

  def ensure_unique_number_digest
    return if number_digest.blank?

    return unless self.class.where(number_digest: number_digest).where.not(id: id).exists?

    errors.add(:number, :taken)
  end

  def enforce_user_telephone_limit
    return unless user_id

    return if self.class.where(user_id: user_id).count < MAX_TELEPHONES_PER_USER

    errors.add(:base, :too_many, message: "exceeds maximum telephones per user (#{MAX_TELEPHONES_PER_USER})")
  end
end

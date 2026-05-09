# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_telephones
# Database name: guest
#
#  id                           :bigint           not null, primary key
#  locked_at                    :datetime         default(-Infinity), not null
#  number                       :string           default(""), not null
#  number_bidx                  :string
#  number_digest                :string
#  otp_attempts_count           :integer          default(0), not null
#  otp_counter                  :text             default(""), not null
#  otp_expires_at               :datetime         default(-Infinity), not null
#  otp_private_key              :string           default(""), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  customer_id                  :bigint           not null
#  customer_telephone_status_id :bigint           default(1), not null
#  public_id                    :string(21)       not null
#
# Indexes
#
#  index_customer_telephones_on_customer_id                   (customer_id)
#  index_customer_telephones_on_customer_telephone_status_id  (customer_telephone_status_id)
#  index_customer_telephones_on_lower_number                  (lower((number)::text)) UNIQUE
#  index_customer_telephones_on_number_bidx                   (number_bidx) UNIQUE WHERE (number_bidx IS NOT NULL)
#  index_customer_telephones_on_number_digest                 (number_digest) UNIQUE WHERE (number_digest IS NOT NULL)
#  index_customer_telephones_on_public_id                     (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (customer_telephone_status_id => customer_telephone_statuses.id)
#
class CustomerTelephone < GuestRecord
  include Telephone
  include PublicId

  self.filter_attributes += %w(number)

  # FIXME: set telephone max is 2
  MAX_TELEPHONES_PER_CUSTOMER = 4

  attribute :customer_telephone_status_id, default: CustomerTelephoneStatus::UNVERIFIED

  belongs_to :customer, inverse_of: :customer_telephones
  belongs_to :customer_telephone_status, optional: true, inverse_of: :customer_telephones

  validates :number, uniqueness: { case_sensitive: false }
  validates :number_bidx,
            uniqueness: { conditions: -> { where.not(number_bidx: nil) } },
            allow_nil: true
  validates :number_digest,
            uniqueness: { conditions: -> { where.not(number_digest: nil) } },
            allow_nil: true
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :otp_counter, presence: true
  validates :otp_private_key, presence: true, length: { maximum: 255 }
  validates :customer_telephone_status_id, numericality: { only_integer: true }
  validate :ensure_unique_number_digest
  validate :enforce_customer_telephone_limit, on: :create

  def to_param
    public_id
  end

  private

  def ensure_unique_number_digest
    return if number_digest.blank?
    return unless self.class.where(number_digest: number_digest).where.not(id: id).exists?

    errors.add(:number, :taken)
  end

  def enforce_customer_telephone_limit
    return unless customer_id

    count = self.class.where(customer_id: customer_id).count
    return if count < MAX_TELEPHONES_PER_CUSTOMER

    errors.add(:base, :too_many, message: "exceeds maximum telephones per customer (#{MAX_TELEPHONES_PER_CUSTOMER})")
  end
end

# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_emails
# Database name: guest
#
#  id                        :bigint           not null, primary key
#  address                   :string           default(""), not null
#  address_bidx              :string
#  address_digest            :string
#  locked_at                 :datetime         default(Infinity), not null
#  notifiable                :boolean          default(TRUE), not null
#  otp_attempts_count        :integer          default(0), not null
#  otp_counter               :text             default(""), not null
#  otp_expires_at            :datetime         default(-Infinity), not null
#  otp_last_sent_at          :datetime         default(-Infinity), not null
#  otp_private_key           :string           default(""), not null
#  promotional               :boolean          default(TRUE), not null
#  subscribable              :boolean          default(TRUE), not null
#  undeletable               :boolean          default(FALSE), not null
#  verification_token_digest :binary
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  customer_email_status_id  :bigint           default(1), not null
#  customer_id               :bigint           not null
#  public_id                 :string(21)       not null
#
# Indexes
#
#  index_customer_emails_on_address_bidx              (address_bidx) UNIQUE WHERE (address_bidx IS NOT NULL)
#  index_customer_emails_on_address_digest            (address_digest) UNIQUE WHERE (address_digest IS NOT NULL)
#  index_customer_emails_on_customer_email_status_id  (customer_email_status_id)
#  index_customer_emails_on_customer_id               (customer_id)
#  index_customer_emails_on_lower_address             (lower((address)::text)) UNIQUE
#  index_customer_emails_on_otp_last_sent_at          (otp_last_sent_at)
#  index_customer_emails_on_public_id                 (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_email_status_id => customer_email_statuses.id)
#  fk_rails_...  (customer_id => customers.id)
#
class CustomerEmail < GuestRecord
  include PublicId
  include Email

  self.filter_attributes += %w(address)

  MAX_EMAILS_PER_CUSTOMER = 4

  attribute :customer_email_status_id, default: CustomerEmailStatus::UNVERIFIED

  belongs_to :customer, inverse_of: :customer_emails
  belongs_to :customer_email_status, optional: true, inverse_of: :customer_emails

  validates :address, uniqueness: { case_sensitive: false }
  validates :address_bidx,
            uniqueness: { conditions: -> { where.not(address_bidx: nil) } },
            allow_nil: true
  validates :address_digest,
            uniqueness: { conditions: -> { where.not(address_digest: nil) } },
            allow_nil: true
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :otp_counter, presence: true
  validates :otp_private_key, presence: true, length: { maximum: 255 }
  validates :customer_email_status_id, numericality: { only_integer: true }
  validate :ensure_unique_address_digest
  validate :enforce_customer_email_limit, on: :create
  before_destroy :prevent_destroy_when_undeletable

  def to_param
    public_id
  end

  def generate_verification_token
    raw_token = SecureRandom.urlsafe_base64(32)
    self.verification_token_digest = Digest::SHA256.hexdigest(raw_token)
    save!
    raw_token
  end

  def verify_verification_token(raw_token)
    return false if raw_token.blank? || verification_token_digest.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      verification_token_digest,
      Digest::SHA256.hexdigest(raw_token),
    )
  end

  private

  def prevent_destroy_when_undeletable
    return unless undeletable?

    errors.add(:base, :undeletable, message: "cannot delete a protected email address")
    throw(:abort)
  end

  def ensure_unique_address_digest
    return if address_digest.blank?
    return unless self.class.where(address_digest: address_digest).where.not(id: id).exists?

    errors.add(:address, :taken)
  end

  def enforce_customer_email_limit
    return unless customer_id

    count = self.class.where(customer_id: customer_id).count
    return if count < MAX_EMAILS_PER_CUSTOMER

    errors.add(:base, :too_many, message: "exceeds maximum emails per customer (#{MAX_EMAILS_PER_CUSTOMER})")
  end
end

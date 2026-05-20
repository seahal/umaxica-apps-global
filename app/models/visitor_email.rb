# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_emails
# Database name: com_principal
#
#  id                        :bigint           not null, primary key
#  address                   :string           default(""), not null
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
#  public_id                 :string(21)       not null
#  visitor_email_status_id   :bigint           default(1), not null
#  visitor_id                :bigint           not null
#
# Indexes
#
#  index_visitor_emails_on_address_digest           (address_digest) UNIQUE WHERE (address_digest IS NOT NULL)
#  index_visitor_emails_on_otp_last_sent_at         (otp_last_sent_at)
#  index_visitor_emails_on_public_id                (public_id) UNIQUE
#  index_visitor_emails_on_visitor_email_status_id  (visitor_email_status_id)
#  index_visitor_emails_on_visitor_id               (visitor_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_email_status_id => visitor_email_statuses.id)
#  fk_rails_...  (visitor_id => visitors.id)
#
class VisitorEmail < ComPrincipalRecord
  include PublicId
  include Email
  include MultiFactorStatusCredential
  include PromotionalEmailUnsubscribable

  self.filter_attributes += %w(address)

  MAX_EMAILS_PER_VISITOR = 4

  attribute :visitor_email_status_id, default: VisitorEmailStatus::UNVERIFIED

  belongs_to :visitor, inverse_of: :visitor_emails
  multi_factor_status_owner :visitor
  belongs_to :visitor_email_status, inverse_of: :visitor_emails

  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :otp_counter, presence: true
  validates :otp_private_key, presence: true, length: { maximum: 255 }
  validates :visitor_email_status_id, numericality: { only_integer: true }
  validate :ensure_unique_address_digest
  validate :enforce_visitor_email_limit, on: :create
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

  def promotional_unsubscribe_scope
    :visitor
  end

  private

  def prevent_destroy_when_undeletable
    return unless undeletable?

    errors.add(:base, :undeletable, message: "cannot delete a protected email address")
    throw(:abort)
  end

  def ensure_unique_address_digest
    return if address_digest.blank?

    operation = -> { self.class.where(address_digest: address_digest).where.not(id: id).exists? }
    return unless defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call

    errors.add(:address, :taken)
  end

  def enforce_visitor_email_limit
    return unless visitor_id

    count =
      if visitor&.visitor_emails&.loaded?
        visitor.visitor_emails.count { |email| email != self }
      else
        operation = -> { self.class.where(visitor_id: visitor_id).count }
        defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
      end
    return if count < MAX_EMAILS_PER_VISITOR

    errors.add(:base, :too_many, message: "exceeds maximum emails per visitor (#{MAX_EMAILS_PER_VISITOR})")
  end
end

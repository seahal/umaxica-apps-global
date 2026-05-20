# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_emails
# Database name: org_principal
#
#  id                             :bigint           not null, primary key
#  address                        :string           not null
#  address_digest                 :string
#  locked_at                      :datetime
#  notifiable                     :boolean          default(TRUE), not null
#  otp_attempts_count             :integer          default(0), not null
#  otp_counter                    :text             not null
#  otp_expires_at                 :datetime
#  otp_last_sent_at               :datetime
#  otp_private_key                :string           not null
#  promotional                    :boolean          default(TRUE), not null
#  subscribable                   :boolean          default(TRUE), not null
#  undeletable                    :boolean          default(FALSE), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  public_id                      :string(21)       default(""), not null
#  staff_id                       :bigint           not null
#  staff_identity_email_status_id :bigint           default(6), not null
#
# Indexes
#
#  index_staff_emails_on_address_digest                  (address_digest) UNIQUE WHERE (address_digest IS NOT NULL)
#  index_staff_emails_on_public_id                       (public_id) UNIQUE
#  index_staff_emails_on_staff_id                        (staff_id)
#  index_staff_emails_on_staff_identity_email_status_id  (staff_identity_email_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (staff_identity_email_status_id => staff_email_statuses.id)
#

class OperatorEmail < OrgPrincipalRecord
  self.table_name = "staff_emails"
  alias_attribute :staff_email_status_id, :staff_identity_email_status_id
  include PublicId
  include Email
  include PromotionalEmailUnsubscribable

  self.filter_attributes += %w(address)

  MAX_EMAILS_PER_STAFF = 4
  attribute :staff_identity_email_status_id, default: OperatorEmailStatus::UNVERIFIED
  belongs_to :staff_email_status, class_name: "OperatorEmailStatus",
                                  foreign_key: :staff_identity_email_status_id,
                                  inverse_of: :staff_emails
  belongs_to :staff, class_name: "Operator"
  validates :address, presence: true, length: { maximum: 255 }
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :otp_counter, presence: true
  validates :otp_private_key, presence: true, length: { maximum: 255 }
  validates :staff_identity_email_status_id, numericality: { only_integer: true }
  validate :ensure_unique_address_digest
  validate :enforce_staff_email_limit, on: :create
  before_destroy :prevent_destroy_when_undeletable
  before_validation do
    self.staff_id ||= 0
  end

  def to_param
    public_id
  end

  after_initialize do
    self.address ||= ""
  end

  def promotional_unsubscribe_scope
    :operator
  end

  private

  def prevent_destroy_when_undeletable
    return unless undeletable?

    errors.add(:base, :undeletable, message: "cannot delete a protected email address")
    throw(:abort)
  end

  def ensure_unique_address_digest
    return if address_digest.blank?

    duplicate =
      if defined?(Prosopite)
        Prosopite.pause do
          self.class.where(address_digest: address_digest).where.not(id: id).exists?
        end
      else
        self.class.where(address_digest: address_digest).where.not(id: id).exists?
      end
    return unless duplicate

    errors.add(:address, :taken)
  end

  def enforce_staff_email_limit
    return unless staff_id

    count =
      if staff&.staff_emails&.loaded?
        staff.staff_emails.count { |email| email != self }
      elsif defined?(Prosopite)
        Prosopite.pause { self.class.where(staff_id: staff_id).count }
      else
        self.class.where(staff_id: staff_id).count
      end
    return if count < MAX_EMAILS_PER_STAFF

    errors.add(:base, :too_many, message: "exceeds maximum emails per staff (#{MAX_EMAILS_PER_STAFF})")
  end
end

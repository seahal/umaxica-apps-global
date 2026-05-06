# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_contacts
# Database name: guest
#
#  id               :bigint           not null, primary key
#  ip_address       :inet
#  token            :string(32)       default(""), not null
#  token_digest     :string
#  token_expires_at :datetime
#  token_viewed     :boolean          default(FALSE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  category_id      :bigint           default(0), not null
#  public_id        :string(21)       not null
#  status_id        :bigint           not null
#
# Indexes
#
#  index_org_contacts_on_category_id       (category_id)
#  index_org_contacts_on_public_id         (public_id) UNIQUE
#  index_org_contacts_on_status_id         (status_id)
#  index_org_contacts_on_token             (token)
#  index_org_contacts_on_token_digest      (token_digest)
#  index_org_contacts_on_token_expires_at  (token_expires_at)
#
# Foreign Keys
#
#  fk_org_contacts_on_status_id_nullify  (status_id => org_contact_statuses.id) ON DELETE => nullify
#  fk_rails_...                          (category_id => org_contact_categories.id)
#

class OrgContact < GuestRecord
  include ::PublicId

  attr_accessor :confirm_policy

  # Associations
  has_many :org_contact_emails, dependent: :destroy, inverse_of: :org_contact
  has_many :org_contact_telephones, dependent: :destroy, inverse_of: :org_contact
  belongs_to :org_contact_category,
             class_name: "OrgContactCategory",
             foreign_key: :category_id,
             primary_key: :id,
             inverse_of: :org_contacts
  belongs_to :org_contact_status,
             class_name: "OrgContactStatus",
             foreign_key: :status_id,
             inverse_of: :org_contacts
  has_many :org_contact_topics, dependent: :destroy, inverse_of: :org_contact
  has_many :org_contact_chronicles,
           class_name: "OrgContactChronicle",
           foreign_key: :subject_id,
           inverse_of: :org_contact,
           dependent: :delete_all

  after_initialize do
    if new_record?
      self.category_id = OrgContactCategory::ORGANIZATION_INQUIRY if category_id.blank? || category_id.to_i.zero?
      self.status_id = OrgContactStatus::NOTHING if status_id.blank? || status_id.to_i.zero?
    end
  end

  # Validations
  validates :confirm_policy, acceptance: true
  validates :token, length: { maximum: 32 }
  validates :token_digest, length: { maximum: 255 }

  # Callbacks
  has_secure_token :token

  # State transition helpers
  def email_pending?
    status_id == OrgContactStatus::SET_UP
  end

  def email_verified?
    status_id == OrgContactStatus::CHECKED_EMAIL_ADDRESS
  end

  def phone_verified?
    status_id == OrgContactStatus::CHECKED_TELEPHONE_NUMBER
  end

  def can_verify_email?
    email_pending?
  end

  def can_verify_phone?
    email_verified?
  end

  def can_complete?
    phone_verified?
  end

  def verify_email!
    transition_status(
      status: OrgContactStatus::CHECKED_EMAIL_ADDRESS,
      error_message: "Cannot verify email at this time",
    ) do
      can_verify_email?
    end
  end

  def verify_phone!
    transition_status(
      status: OrgContactStatus::CHECKED_TELEPHONE_NUMBER,
      error_message: "Cannot verify phone at this time",
    ) do
      can_verify_phone?
    end
  end

  def complete!
    transition_status(
      status: OrgContactStatus::COMPLETED_CONTACT_ACTION,
      error_message: "Cannot complete contact at this time",
    ) do
      can_complete?
    end
  end

  # Token management
  def generate_final_token
    raw_token = SecureRandom.alphanumeric(32)
    self.token_digest = Argon2::Password.create(raw_token)
    self.token_expires_at = 7.days.from_now
    self.token_viewed = false
    save!
    raw_token # Return raw token only once
  end

  def verify_token(raw_token)
    return false if token_viewed?
    return false if token_expires_at && Time.current >= token_expires_at
    return false unless token_digest

    if Argon2::Password.verify_password(raw_token, token_digest)
      update!(token_viewed: true)
      true
    else
      false
    end
  end

  def token_expired?
    return false if token_expires_at.to_s == "-Infinity"

    token_expires_at && Time.current >= token_expires_at
  end

  # Override to_param to use public_id in URLs
  def to_param
    public_id
  end

  private

  def transition_status(status:, error_message:)
    return update(status_id: status) if yield

    errors.add(:base, error_message)
    false
  end
end

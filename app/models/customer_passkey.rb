# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_passkeys
# Database name: guest
#
#  id           :bigint           not null, primary key
#  description  :string           default(""), not null
#  last_used_at :datetime
#  public_key   :text             not null
#  sign_count   :bigint           default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  customer_id  :bigint           not null
#  external_id  :uuid             not null
#  public_id    :string(21)       not null
#  status_id    :bigint           default(1), not null
#  webauthn_id  :string           default(""), not null
#
# Indexes
#
#  index_customer_passkeys_on_customer_id  (customer_id)
#  index_customer_passkeys_on_public_id    (public_id) UNIQUE
#  index_customer_passkeys_on_status_id    (status_id)
#  index_customer_passkeys_on_webauthn_id  (webauthn_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (status_id => customer_passkey_statuses.id)
#
class CustomerPasskey < GuestRecord
  include PublicId

  MAX_PASSKEYS_PER_CUSTOMER = 4

  attribute :status_id, default: CustomerPasskeyStatus::ACTIVE

  belongs_to :customer, inverse_of: :customer_passkeys
  belongs_to :status, class_name: "CustomerPasskeyStatus", optional: true

  scope :active, -> { where(status_id: CustomerPasskeyStatus::ACTIVE) }

  validates :webauthn_id, presence: true, uniqueness: true
  validates :external_id, presence: true
  validates :public_key, presence: true
  validates :description, presence: true
  validates :status_id, numericality: { only_integer: true }
  validates :sign_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :enforce_customer_passkey_limit, on: :create
  validate :require_verified_recovery_identity, on: :create

  before_validation :set_defaults, on: :create

  def to_param
    public_id
  end

  private

  def enforce_customer_passkey_limit
    return unless customer_id

    count = self.class.where(customer_id: customer_id).count
    return if count < MAX_PASSKEYS_PER_CUSTOMER

    errors.add(:base, :too_many, message: "exceeds maximum passkeys per customer (#{MAX_PASSKEYS_PER_CUSTOMER})")
  end

  def require_verified_recovery_identity
    return if customer&.has_verified_recovery_identity?

    errors.add(:base, Customer::RECOVERY_IDENTITY_REQUIRED_MESSAGE)
  end

  def set_defaults
    self.external_id ||= SecureRandom.uuid
    self.sign_count ||= 0
    self.description = I18n.t("sign.default_passkey_description") if description.blank?
  end
end

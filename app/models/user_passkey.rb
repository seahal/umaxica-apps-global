# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_passkeys
# Database name: principal
#
#  id           :bigint           not null, primary key
#  description  :string           default(""), not null
#  last_used_at :datetime
#  public_key   :text             not null
#  sign_count   :bigint           default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  external_id  :uuid             not null
#  public_id    :string(21)       not null
#  status_id    :bigint           default(1), not null
#  user_id      :bigint           not null
#  webauthn_id  :string           default(""), not null
#
# Indexes
#
#  index_user_identity_passkeys_on_user_id  (user_id)
#  index_user_passkeys_on_public_id         (public_id) UNIQUE
#  index_user_passkeys_on_status_id         (status_id)
#  index_user_passkeys_on_webauthn_id       (webauthn_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (status_id => user_passkey_statuses.id)
#  fk_rails_...  (user_id => users.id)
#

class UserPasskey < PrincipalRecord
  include ::PublicId

  MAX_PASSKEYS_PER_USER = 4
  attribute :status_id, default: UserPasskeyStatus::ACTIVE

  belongs_to :user, inverse_of: :user_passkeys
  belongs_to :status, class_name: "UserPasskeyStatus", optional: true

  scope :active, -> { where(status_id: UserPasskeyStatus::ACTIVE) }

  validates :webauthn_id, presence: true, uniqueness: true
  validates :external_id, presence: true
  validates :public_key, presence: true
  validates :description, presence: true
  validates :status_id, numericality: { only_integer: true }
  validates :sign_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :enforce_user_passkey_limit, on: :create
  validate :require_verified_recovery_identity, on: :create

  before_validation :set_defaults, on: :create

  def to_param
    public_id
  end

  private

  def enforce_user_passkey_limit
    return unless user_id

    count = self.class.where(user_id: user_id).count
    return if count < MAX_PASSKEYS_PER_USER

    errors.add(:base, :too_many, message: "exceeds maximum passkeys per user (#{MAX_PASSKEYS_PER_USER})")
  end

  def require_verified_recovery_identity
    return if user&.has_verified_recovery_identity?

    errors.add(:base, User::RECOVERY_IDENTITY_REQUIRED_MESSAGE)
  end

  def set_defaults
    self.external_id ||= SecureRandom.uuid
    self.sign_count ||= 0
    self.description = I18n.t("sign.default_passkey_description") if description.blank?
  end
end

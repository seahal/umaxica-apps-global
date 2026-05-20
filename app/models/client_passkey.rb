# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_passkeys
# Database name: app_principal
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

class ClientPasskey < AppPrincipalRecord
  self.table_name = "user_passkeys"
  include ::PublicId
  include MultiFactorStatusCredential

  MAX_PASSKEYS_PER_USER = 4
  attribute :status_id, default: ClientPasskeyStatus::ACTIVE

  belongs_to :user, class_name: "Client", inverse_of: :client_passkeys
  multi_factor_status_owner :user
  belongs_to :status, class_name: "ClientPasskeyStatus"

  scope :active, -> { where(status_id: ClientPasskeyStatus::ACTIVE) }

  validates :webauthn_id, presence: true, uniqueness: true
  validates :external_id, presence: true
  validates :public_key, presence: true
  validates :description, presence: true
  validates :status_id, numericality: { only_integer: true }
  validates :sign_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :enforce_user_passkey_limit, on: :create

  before_validation :set_defaults, on: :create
  before_validation :ensure_status_defaults, on: :create

  def to_param
    public_id
  end

  private

  def enforce_user_passkey_limit
    return unless user_id

    count =
      if user&.client_passkeys&.loaded?
        user.client_passkeys.count { |passkey| passkey != self }
      elsif defined?(Prosopite)
        Prosopite.pause { self.class.where(user_id: user_id).count }
      else
        self.class.where(user_id: user_id).count
      end
    return if count < MAX_PASSKEYS_PER_USER

    errors.add(:base, :too_many, message: "exceeds maximum passkeys per user (#{MAX_PASSKEYS_PER_USER})")
  end

  def set_defaults
    self.external_id ||= SecureRandom.uuid
    self.sign_count ||= 0
    self.description = I18n.t("sign.default_passkey_description") if description.blank?
  end

  def ensure_status_defaults
    ClientPasskeyStatus.ensure_defaults!
  end
end

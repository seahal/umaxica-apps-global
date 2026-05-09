# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_secrets
# Database name: principal
#
#  id                             :bigint           not null, primary key
#  lapses_at                      :datetime         default(Infinity), not null
#  last_used_at                   :datetime
#  name                           :string           default(""), not null
#  password_digest                :string           default(""), not null
#  purge_at                       :datetime         default(Infinity), not null
#  uses_remaining                 :integer          default(1), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  public_id                      :string(21)       not null
#  user_id                        :bigint           not null
#  user_identity_secret_status_id :bigint           default(1), not null
#  user_secret_kind_id            :bigint           default(1), not null
#
# Indexes
#
#  index_user_secrets_on_public_id                       (public_id) UNIQUE
#  index_user_secrets_on_user_id                         (user_id)
#  index_user_secrets_on_user_identity_secret_status_id  (user_identity_secret_status_id)
#  index_user_secrets_on_user_secret_kind_id             (user_secret_kind_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (user_identity_secret_status_id => user_secret_statuses.id)
#  fk_rails_...  (user_secret_kind_id => user_secret_kinds.id)
#

class UserSecret < PrincipalRecord
  include Retainable

  alias_attribute :user_secret_status_id, :user_identity_secret_status_id
  include ::PublicId
  include ::Secret
  include UserSecret::Kinds

  MAX_SECRETS_PER_USER = 10
  SIGN_IN_ALLOWED_STATUS_IDS = [UserSecretStatus::ACTIVE].freeze
  SIGN_IN_ALLOWED_KIND_IDS = UserSecretKind::ALLOWED_FOR_SECRET_SIGN_IN
  attr_accessor :raw_secret

  attribute :user_identity_secret_status_id, default: UserSecretStatus::ACTIVE
  attribute :user_secret_kind_id, default: UserSecretKind::LOGIN

  belongs_to :user, inverse_of: :user_secrets
  belongs_to :user_secret_status, inverse_of: :user_secrets, foreign_key: :user_identity_secret_status_id
  belongs_to :user_secret_kind, inverse_of: :user_secrets

  validates :name, length: { maximum: 255 }
  validates :password_digest, presence: true, length: { maximum: 255 }

  validate :enforce_secret_limit, on: :create
  validate :require_verified_recovery_identity, on: :create

  scope :allowed_for_secret_sign_in, lambda {
    where(
      user_identity_secret_status_id: SIGN_IN_ALLOWED_STATUS_IDS,
      user_secret_kind_id: SIGN_IN_ALLOWED_KIND_IDS,
    )
  }

  def self.identity_secret_status_class
    UserSecretStatus
  end

  def self.identity_secret_status_id_column
    :user_identity_secret_status_id
  end

  def self.generate_raw_secret(length: SECRET_PASSWORD_LENGTH)
    SecureRandom.base58(length)
  end

  # Alias for password to match controller params
  def value=(val)
    self.password = val
  end

  def value
    password
  end

  def enabled?
    active?
  end

  def usable_for_secret_sign_in?(now: Time.current)
    return false unless sign_in_status_allowed?
    return false unless sign_in_kind_allowed?
    return false if expired_for_secret_sign_in?(now)
    return true if permanent_secret?

    Integer(uses_remaining.to_s, 10).positive?
  end

  def verify_for_secret_sign_in!(raw_secret, now: Time.current)
    with_lock do
      reload

      auth_result = authenticate(raw_secret)
      return false unless sign_in_status_allowed?
      return false unless sign_in_kind_allowed?
      return false if expired_for_secret_sign_in?(now)
      return false unless auth_result

      self.last_used_at = now
      if one_time_secret?
        return false unless Integer(uses_remaining.to_s, 10).positive?

        self.uses_remaining -= 1
        self[self.class.identity_secret_status_id_column] = self.class.status_id_for(:used) if uses_remaining.zero?
      end

      save!
    end

    true
  end

  def to_param
    public_id
  end

  private

  def sign_in_status_allowed?
    SIGN_IN_ALLOWED_STATUS_IDS.include?(user_secret_status_id)
  end

  def sign_in_kind_allowed?
    SIGN_IN_ALLOWED_KIND_IDS.include?(user_secret_kind_id)
  end

  # Secret sign-in keeps expiry inclusive: now <= expires_at is valid.
  def expired_for_secret_sign_in?(now)
    return false if lapses_at.nil?
    return false if lapses_at.respond_to?(:infinite?) && lapses_at.infinite?

    now > lapses_at
  end

  def enforce_secret_limit
    return unless user_id

    count = self.class.where(user_id: user_id).count
    return if count < MAX_SECRETS_PER_USER

    errors.add(:base, :too_many, message: "exceeds maximum secrets per user (#{MAX_SECRETS_PER_USER})")
  end

  def require_verified_recovery_identity
    return if user&.has_verified_recovery_identity?

    errors.add(:base, User::RECOVERY_IDENTITY_REQUIRED_MESSAGE)
  end
end

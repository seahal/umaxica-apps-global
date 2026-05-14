# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_secrets
# Database name: guest
#
#  id                       :bigint           not null, primary key
#  lapses_at                :datetime         default(Infinity), not null
#  last_used_at             :datetime
#  name                     :string           default(""), not null
#  password_digest          :string           default(""), not null
#  purge_at                 :datetime         default(Infinity), not null
#  uses_remaining           :integer          default(1), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  public_id                :string(21)       not null
#  visitor_id               :bigint           not null
#  visitor_secret_kind_id   :bigint           default(1), not null
#  visitor_secret_status_id :bigint           default(1), not null
#
# Indexes
#
#  index_visitor_secrets_on_public_id                 (public_id) UNIQUE
#  index_visitor_secrets_on_visitor_id                (visitor_id)
#  index_visitor_secrets_on_visitor_secret_kind_id    (visitor_secret_kind_id)
#  index_visitor_secrets_on_visitor_secret_status_id  (visitor_secret_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_id => visitors.id)
#  fk_rails_...  (visitor_secret_kind_id => visitor_secret_kinds.id)
#  fk_rails_...  (visitor_secret_status_id => visitor_secret_statuses.id)
#
class VisitorSecret < GuestRecord
  include Retainable
  include PublicId
  include Secret
  include VisitorSecret::Kinds

  MAX_SECRETS_PER_VISITOR = 10
  SIGN_IN_ALLOWED_STATUS_IDS = [VisitorSecretStatus::ACTIVE].freeze
  SIGN_IN_ALLOWED_KIND_IDS = VisitorSecretKind::ALLOWED_FOR_SECRET_SIGN_IN

  attr_accessor :raw_secret

  attribute :visitor_secret_status_id, default: VisitorSecretStatus::ACTIVE
  attribute :visitor_secret_kind_id, default: VisitorSecretKind::LOGIN

  belongs_to :visitor, inverse_of: :visitor_secrets
  belongs_to :visitor_secret_status, inverse_of: :visitor_secrets, optional: true
  belongs_to :visitor_secret_kind, inverse_of: :visitor_secrets

  validates :name, length: { maximum: 255 }
  validates :password_digest, presence: true, length: { maximum: 255 }
  validates :visitor_secret_status_id, numericality: { only_integer: true }
  validates :visitor_secret_kind_id, numericality: { only_integer: true }
  validate :enforce_secret_limit, on: :create
  validate :require_verified_recovery_identity, on: :create

  scope :allowed_for_secret_sign_in, lambda {
    where(
      visitor_secret_status_id: SIGN_IN_ALLOWED_STATUS_IDS,
      visitor_secret_kind_id: SIGN_IN_ALLOWED_KIND_IDS,
    )
  }

  def self.identity_secret_status_class
    VisitorSecretStatus
  end

  def self.identity_secret_status_id_column
    :visitor_secret_status_id
  end

  def self.generate_raw_secret(length: SECRET_PASSWORD_LENGTH)
    SecureRandom.base58(length)
  end

  def value=(val)
    self.password = val
  end

  def value
    password
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
    SIGN_IN_ALLOWED_STATUS_IDS.include?(visitor_secret_status_id)
  end

  def sign_in_kind_allowed?
    SIGN_IN_ALLOWED_KIND_IDS.include?(visitor_secret_kind_id)
  end

  def expired_for_secret_sign_in?(now)
    return false if lapses_at.nil?
    return false if lapses_at.respond_to?(:infinite?) && lapses_at.infinite?

    now > lapses_at
  end

  def enforce_secret_limit
    return unless visitor_id

    count = self.class.where(visitor_id: visitor_id).count
    return if count < MAX_SECRETS_PER_VISITOR

    errors.add(:base, :too_many, message: "exceeds maximum secrets per visitor (#{MAX_SECRETS_PER_VISITOR})")
  end

  def require_verified_recovery_identity
    return if visitor&.has_verified_recovery_identity?

    errors.add(:base, Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE)
  end
end

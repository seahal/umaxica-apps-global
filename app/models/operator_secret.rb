# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_secrets
# Database name: org_principal
#
#  id                              :bigint           not null, primary key
#  discarded_at                    :datetime         default(Infinity), not null
#  last_used_at                    :datetime
#  name                            :string           not null
#  password_digest                 :string
#  purged_at                       :datetime         default(Infinity), not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  public_id                       :string(21)       not null
#  staff_id                        :bigint           not null
#  staff_identity_secret_status_id :bigint           default(1), not null
#  staff_secret_kind_id            :bigint           default(2), not null
#
# Indexes
#
#  index_staff_secrets_on_public_id                        (public_id) UNIQUE
#  index_staff_secrets_on_staff_id                         (staff_id)
#  index_staff_secrets_on_staff_identity_secret_status_id  (staff_identity_secret_status_id)
#  index_staff_secrets_on_staff_secret_kind_id             (staff_secret_kind_id)
#
# Foreign Keys
#
#  fk_rails_...                              (staff_id => operators.id)
#  fk_rails_...                              (staff_identity_secret_status_id => staff_secret_statuses.id)
#  fk_staff_secrets_on_staff_secret_kind_id  (staff_secret_kind_id => staff_secret_kinds.id)
#

class OperatorSecret < OrgPrincipalRecord
  self.table_name = "staff_secrets"
  include Retainable

  alias_attribute :staff_secret_status_id, :staff_identity_secret_status_id
  include ::PublicId
  include ::Secret
  include OperatorSecret::Kinds

  MAX_SECRETS_PER_STAFF = 10
  SIGN_IN_ALLOWED_STATUS_IDS = [OperatorSecretStatus::ACTIVE].freeze
  SIGN_IN_ALLOWED_KIND_IDS = OperatorSecretKind::ALLOWED_FOR_SECRET_SIGN_IN
  attr_accessor :raw_secret

  attribute :staff_identity_secret_status_id, default: OperatorSecretStatus::ACTIVE
  attribute :staff_secret_kind_id, default: OperatorSecretKind::LOGIN

  belongs_to :staff, class_name: "Operator"
  belongs_to :staff_secret_status, class_name: "OperatorSecretStatus", inverse_of: :staff_secrets,
                                   foreign_key: :staff_identity_secret_status_id
  belongs_to :staff_secret_kind, class_name: "OperatorSecretKind", inverse_of: :staff_secrets

  validates :staff_identity_secret_status_id, numericality: { only_integer: true }
  validates :staff_secret_kind_id, numericality: { only_integer: true }
  validate :enforce_secret_limit, on: :create

  scope :allowed_for_secret_sign_in, lambda {
    where(
      staff_identity_secret_status_id: SIGN_IN_ALLOWED_STATUS_IDS,
      staff_secret_kind_id: SIGN_IN_ALLOWED_KIND_IDS,
    )
  }

  def self.identity_secret_status_class
    OperatorSecretStatus
  end

  def self.identity_secret_status_id_column
    :staff_identity_secret_status_id
  end

  def self.generate_raw_secret(length: SECRET_PASSWORD_LENGTH)
    SecureRandom.base58(length)
  end

  def to_param
    public_id
  end

  def usable_for_secret_sign_in?(now: Time.current)
    return false unless sign_in_status_allowed?
    return false unless sign_in_kind_allowed?
    return false if expired_for_secret_sign_in?(now)

    true
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
      save!
    end

    true
  end

  private

  def sign_in_status_allowed?
    SIGN_IN_ALLOWED_STATUS_IDS.include?(staff_secret_status_id)
  end

  def sign_in_kind_allowed?
    SIGN_IN_ALLOWED_KIND_IDS.include?(staff_secret_kind_id)
  end

  def expired_for_secret_sign_in?(now)
    return false unless respond_to?(:expires_at)
    return false if expires_at.nil?
    return false if expires_at.is_a?(Float) && expires_at.infinite?

    comparable_time = expires_at.is_a?(Float) ? Time.zone.at(expires_at) : expires_at
    now > comparable_time
  end

  def enforce_secret_limit
    return unless staff_id

    count =
      if staff&.staff_secrets&.loaded?
        staff.staff_secrets.count { |secret| secret != self }
      elsif defined?(Prosopite)
        Prosopite.pause { self.class.where(staff_id: staff_id).count }
      else
        self.class.where(staff_id: staff_id).count
      end
    return if count < MAX_SECRETS_PER_STAFF

    errors.add(:base, :too_many, message: "exceeds maximum secrets per staff (#{MAX_SECRETS_PER_STAFF})")
  end
end

# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operators
# Database name: operator
#
#  id                     :bigint           not null, primary key
#  lapses_at              :datetime         default(Infinity), not null
#  lock_version           :integer          default(0), not null
#  multi_factor_enabled   :boolean          default(FALSE), not null
#  purge_at               :datetime         default(Infinity), not null
#  withdrawn_at           :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  multi_factor_id        :bigint           default(0), not null
#  multi_factor_status_id :bigint           default(5), not null
#  public_id              :string(16)       not null
#  status_id              :bigint           default(2), not null
#  visibility_id          :bigint           default(2), not null
#
# Indexes
#
#  index_operators_on_multi_factor_id         (multi_factor_id)
#  index_operators_on_multi_factor_status_id  (multi_factor_status_id)
#  index_operators_on_public_id               (public_id) UNIQUE
#  index_operators_on_purge_at                (purge_at)
#  index_operators_on_status_id               (status_id)
#  index_operators_on_visibility_id           (visibility_id)
#  index_operators_on_withdrawn_at            (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (multi_factor_id => staff_multi_factors.id)
#  fk_rails_...  (multi_factor_status_id => staff_multi_factor_statuses.id)
#  fk_rails_...  (status_id => staff_statuses.id)
#  fk_rails_...  (visibility_id => staff_visibilities.id)
#

class Operator < OperatorRecord
  include Retainable

  # Operator represents an authenticated actor for the org console.
  # It mirrors `User` for identity concerns but is used for org-scoped access.
  self.ignored_columns += ["operator_id", "webauthn_id"]

  include ::Identity
  include MultiFactorConfigurable
  include MultiFactorStatusTrackable

  LOGIN_BLOCKED_STATUS_IDS = [OperatorIdentityStatus::RESERVED].freeze
  PUBLIC_ID_LENGTH = 16
  PUBLIC_ID_ALPHABET = SecureRandom::BASE32_ALPHABET.join.freeze
  PUBLIC_ID_FORMAT = /\A[0-9A-FGHJKMNPQRSTVWXYZ]{16}\z/
  MAX_PUBLIC_ID_RETRIES = 5

  attribute :status_id, default: OperatorIdentityStatus::NOTHING
  multi_factor_reference OperatorMultiFactor
  multi_factor_status_reference OperatorMultiFactorStatus

  belongs_to :staff_status, class_name: "OperatorIdentityStatus", foreign_key: :status_id,
                            inverse_of: :staffs
  belongs_to :multi_factor,
             class_name: "OperatorMultiFactor",
             inverse_of: :staffs
  belongs_to :multi_factor_status,
             class_name: "OperatorMultiFactorStatus",
             inverse_of: :staffs
  belongs_to :visibility,
             class_name: "OperatorVisibility",
             inverse_of: :staffs
  has_many :staff_emails, class_name: "OperatorEmail", dependent: :restrict_with_error,
                          inverse_of: :staff
  has_many :staff_telephones, class_name: "OperatorTelephone", dependent: :restrict_with_error,
                              inverse_of: :staff
  has_many :staff_passkeys, class_name: "OperatorPasskey", dependent: :destroy,
                            inverse_of: :staff
  has_many :staff_chronicles,
           -> { where(subject_type: "Operator") },
           class_name: "OperatorChronicle",
           foreign_key: :subject_id,
           dependent: :nullify,
           inverse_of: false
  has_many :user_chronicles,
           as: :actor,
           dependent: :nullify
  has_many :staff_secrets, class_name: "OperatorSecret", dependent: :destroy,
                           inverse_of: :staff
  has_many :staff_tokens, class_name: "OperatorToken", dependent: :destroy,
                          inverse_of: :staff
  has_many :staff_notifications, class_name: "StaffNotification", dependent: :destroy,
                                 inverse_of: :staff
  has_many :staff_operators, class_name: "OperatorAccountMembership", dependent: :destroy,
                             inverse_of: :staff
  has_many :operator_accounts,
           class_name: "OperatorAccount",
           foreign_key: :staff_id,
           inverse_of: :operator,
           dependent: :destroy
  has_many :staff_bulletins, class_name: "OperatorBulletin", dependent: :destroy, inverse_of: :staff
  has_many :staff_banners, class_name: "OperatorBanner", dependent: :destroy, inverse_of: :staff
  has_many :staff_org_preferences, class_name: "OperatorOrgPreference", foreign_key: :staff_id,
                                   dependent: :delete_all,
                                   inverse_of: :staff
  has_one :staff_account, class_name: "OperatorPersonnelAccount", dependent: :destroy, inverse_of: :staff
  has_one :staff_preference, class_name: "OperatorPreference", dependent: :destroy, inverse_of: :staff

  validates :public_id,
            presence: true,
            uniqueness: true,
            length: { is: PUBLIC_ID_LENGTH },
            format: {
              with: PUBLIC_ID_FORMAT,
              message: :invalid_format,
            }
  before_validation :normalize_public_id
  before_validation :assign_public_id!, on: :create
  before_save :normalize_public_id
  around_create :retry_on_public_id_collision

  def operator?
    true
  end

  def user?
    false
  end

  def self.generate_public_id
    Array.new(PUBLIC_ID_LENGTH) { PUBLIC_ID_ALPHABET[SecureRandom.random_number(PUBLIC_ID_ALPHABET.length)] }.join
  end

  delegate :generate_public_id, to: :class

  def public_id=(value)
    @public_id_supplied = true unless @_assigning_public_id_internally
    super
  end

  def self.normalize_public_id(value)
    return value if value.nil?

    value.strip.gsub(/[-_]/, "").upcase
  end

  private

  def configured_multi_factor_methods
    staff_passkeys.active.exists? ? [:passkey] : []
  end

  def normalize_public_id
    return if public_id.nil?

    assign_public_id_value(self.class.normalize_public_id(public_id))
  end

  def assign_public_id!
    return if public_id.present? || explicit_blank_public_id_input?

    loop do
      assign_public_id_value(generate_public_id)
      break unless self.class.exists?(public_id: public_id)
    end
  end

  def retry_on_public_id_collision
    attempts = 0

    begin
      yield
    rescue ActiveRecord::RecordNotUnique => e
      attempts += 1

      if attempts <= MAX_PUBLIC_ID_RETRIES
        assign_public_id_value(nil)
        assign_public_id!
        retry
      end

      Rails.logger.error(
        "[Operator] Failed to generate unique public_id after #{MAX_PUBLIC_ID_RETRIES} retries: " \
        "#{e.class}: #{e.message} (last public_id=#{public_id.inspect})",
      )
      Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace
      raise
    end
  end

  def explicit_blank_public_id_input?
    @public_id_supplied && self.class.normalize_public_id(public_id).blank?
  end

  def assign_public_id_value(value)
    @_assigning_public_id_internally = true
    self.public_id = value
  ensure
    @_assigning_public_id_internally = false
  end
end

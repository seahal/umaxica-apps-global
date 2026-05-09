# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staffs
# Database name: operator
#
#  id                   :bigint           not null, primary key
#  lapses_at            :datetime         default(Infinity), not null
#  lock_version         :integer          default(0), not null
#  multi_factor_enabled :boolean          default(FALSE), not null
#  purge_at             :datetime         default(Infinity), not null
#  withdrawn_at         :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  public_id            :string(16)       not null
#  status_id            :bigint           default(2), not null
#  visibility_id        :bigint           default(2), not null
#
# Indexes
#
#  index_staffs_on_public_id      (public_id) UNIQUE
#  index_staffs_on_purge_at       (purge_at)
#  index_staffs_on_status_id      (status_id)
#  index_staffs_on_visibility_id  (visibility_id)
#  index_staffs_on_withdrawn_at   (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => staff_statuses.id)
#  fk_rails_...  (visibility_id => staff_visibilities.id)
#

class Staff < OperatorRecord
  include Retainable

  # Staff represents an operator accountably for the staff/operator console.
  # It mirrors `User` for identity concerns but is used for staff-scoped access.
  self.ignored_columns += ["operator_id", "webauthn_id"]

  include ::Identity

  LOGIN_BLOCKED_STATUS_IDS = [StaffStatus::RESERVED].freeze
  PUBLIC_ID_LENGTH = 16
  PUBLIC_ID_ALPHABET = SecureRandom::BASE32_ALPHABET.join.freeze
  PUBLIC_ID_FORMAT = /\A[0-9A-FGHJKMNPQRSTVWXYZ]{16}\z/
  MAX_PUBLIC_ID_RETRIES = 5

  attribute :status_id, default: StaffStatus::NOTHING

  belongs_to :staff_status,
             foreign_key: :status_id,
             inverse_of: :staffs
  belongs_to :visibility,
             class_name: "StaffVisibility",
             inverse_of: :staffs
  has_many :staff_emails,
           dependent: :restrict_with_error,
           inverse_of: :staff
  has_many :staff_telephones,
           dependent: :restrict_with_error,
           inverse_of: :staff
  has_many :staff_passkeys,
           dependent: :destroy,
           inverse_of: :staff
  has_many :staff_chronicles,
           -> { where(subject_type: "Staff") },
           foreign_key: :subject_id,
           dependent: :nullify,
           inverse_of: false
  has_many :user_chronicles,
           as: :actor,
           dependent: :nullify
  has_many :staff_secrets,
           dependent: :destroy,
           inverse_of: :staff
  has_many :staff_tokens,
           dependent: :destroy,
           inverse_of: :staff
  has_many :staff_notifications,
           dependent: :destroy,
           inverse_of: :staff
  has_many :staff_operators,
           dependent: :destroy,
           inverse_of: :staff
  has_many :operators,
           class_name: "Operator",
           inverse_of: :staff,
           dependent: :destroy
  has_many :staff_bulletins, dependent: :destroy, inverse_of: :staff
  has_many :staff_org_preferences, dependent: :delete_all
  has_one :staff_preference, dependent: :destroy, inverse_of: :staff

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

  def staff?
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
        "[Staff] Failed to generate unique public_id after #{MAX_PUBLIC_ID_RETRIES} retries: " \
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

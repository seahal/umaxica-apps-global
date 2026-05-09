# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_tokens
# Database name: token
#
#  id                            :bigint           not null, primary key
#  dbsc_challenge                :text
#  dbsc_challenge_issued_at      :datetime
#  dbsc_public_key               :jsonb
#  device_id_digest              :string
#  dpop_jkt                      :string
#  lapses_at                     :datetime         default(Infinity), not null
#  last_step_up_at               :datetime
#  last_step_up_scope            :string
#  last_used_at                  :datetime
#  purge_at                      :datetime         default(Infinity), not null
#  refresh_token_digest          :binary
#  refresh_token_generation      :integer          default(0), not null
#  rotated_at                    :datetime
#  status                        :string(20)       default("active"), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  dbsc_session_id               :string
#  device_id                     :string           default(""), not null
#  public_id                     :string(21)       default(""), not null
#  refresh_token_family_id       :string
#  session_id                    :string
#  staff_id                      :bigint           not null
#  staff_token_binding_method_id :bigint           default(0), not null
#  staff_token_dbsc_status_id    :bigint           default(0), not null
#  staff_token_kind_id           :bigint           default(1), not null
#  staff_token_status_id         :bigint           default(0), not null
#
# Indexes
#
#  index_staff_tokens_on_dbsc_session_id                (dbsc_session_id) UNIQUE
#  index_staff_tokens_on_device_id                      (device_id)
#  index_staff_tokens_on_device_id_digest               (device_id_digest)
#  index_staff_tokens_on_public_id                      (public_id) UNIQUE
#  index_staff_tokens_on_purge_at                       (purge_at)
#  index_staff_tokens_on_refresh_token_digest           (refresh_token_digest) UNIQUE
#  index_staff_tokens_on_refresh_token_family_id        (refresh_token_family_id)
#  index_staff_tokens_on_session_id                     (session_id)
#  index_staff_tokens_on_staff_id_and_last_step_up_at   (staff_id,last_step_up_at)
#  index_staff_tokens_on_staff_token_binding_method_id  (staff_token_binding_method_id)
#  index_staff_tokens_on_staff_token_dbsc_status_id     (staff_token_dbsc_status_id)
#  index_staff_tokens_on_staff_token_kind_id            (staff_token_kind_id)
#  index_staff_tokens_on_staff_token_status_id          (staff_token_status_id)
#  index_staff_tokens_on_status                         (status)
#
# Foreign Keys
#
#  fk_staff_tokens_on_staff_token_binding_method_id  (staff_token_binding_method_id => staff_token_binding_methods.id)
#  fk_staff_tokens_on_staff_token_dbsc_status_id     (staff_token_dbsc_status_id => staff_token_dbsc_statuses.id)
#  fk_staff_tokens_on_staff_token_kind_id            (staff_token_kind_id => staff_token_kinds.id)
#  fk_staff_tokens_on_staff_token_status_id          (staff_token_status_id => staff_token_statuses.id)
#

# Refresh tokens are persisted as digests only.
# The public_id is used as the session identifier (sid).
class StaffToken < TokenRecord
  include ::PublicId
  include ::RefreshTokenable
  include ::SignedSessionReference
  include ::Retainable
  include ::TokenStatusManagement
  include ::DbscBindable

  DBSC_BINDING_METHOD_CLASS = StaffTokenBindingMethod
  DBSC_STATUS_CLASS = StaffTokenDbscStatus

  LOGIN_SESSION_TTL = 12.hours
  DELETION_GRACE_PERIOD = 1.day
  MAX_SESSIONS_PER_STAFF = 1
  MAX_TOTAL_SESSIONS_PER_STAFF = 2

  belongs_to :staff
  belongs_to :staff_token_status
  belongs_to :staff_token_kind, optional: true
  belongs_to :staff_token_binding_method
  belongs_to :staff_token_dbsc_status
  has_many :staff_verifications, dependent: :delete_all, inverse_of: :staff_token
  attribute :staff_token_status_id, default: StaffTokenStatus::NOTHING
  attribute :staff_token_kind_id, default: StaffTokenKind::BROWSER_WEB
  attribute :staff_token_binding_method_id, default: StaffTokenBindingMethod::NOTHING
  attribute :staff_token_dbsc_status_id, default: StaffTokenDbscStatus::NOTHING

  validates :public_id, uniqueness: true, length: { maximum: 21 }

  before_create :ensure_session_id

  validate :enforce_concurrent_session_limit, on: :create

  private

  def ensure_session_id
    self.session_id = public_id if session_id.blank?
  end

  # This is a model-level validation to provide a friendly error message to the user.
  # The primary enforcement of the session limit is done by a database trigger,
  # which is more reliable and avoids race conditions.
  #
  # Staff are allowed one fully active session plus one restricted session that can
  # only be used to manage sessions, so the total live row limit is two.
  def enforce_concurrent_session_limit
    return unless staff_id

    count = self.class.not_revoked.where(staff_id: staff_id, rotated_at: nil).count
    return if count < MAX_TOTAL_SESSIONS_PER_STAFF

    errors.add(
      :base, :too_many,
      message: "exceeds maximum concurrent sessions per staff (#{MAX_TOTAL_SESSIONS_PER_STAFF})",
    )
  end
end

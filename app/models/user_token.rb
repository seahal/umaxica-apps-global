# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_tokens
# Database name: mark
#
#  id                           :bigint           not null, primary key
#  compromised_at               :datetime
#  dbsc_challenge               :text
#  dbsc_challenge_issued_at     :datetime
#  dbsc_public_key              :jsonb
#  deletable_at                 :datetime         default(Infinity), not null
#  device_id_digest             :string
#  expired_at                   :datetime
#  last_step_up_at              :datetime
#  last_step_up_scope           :string
#  last_used_at                 :datetime
#  refresh_expires_at           :datetime         not null
#  refresh_token_digest         :binary
#  refresh_token_generation     :integer          default(0), not null
#  revoked_at                   :datetime
#  rotated_at                   :datetime
#  status                       :string(20)       default("active"), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  dbsc_session_id              :string
#  device_id                    :string           default(""), not null
#  public_id                    :string(21)       default(""), not null
#  refresh_token_family_id      :string
#  user_id                      :bigint           not null
#  user_token_binding_method_id :bigint           default(0), not null
#  user_token_dbsc_status_id    :bigint           default(0), not null
#  user_token_kind_id           :bigint           default(11), not null
#  user_token_status_id         :bigint           default(0), not null
#
# Indexes
#
#  index_user_tokens_on_compromised_at                (compromised_at)
#  index_user_tokens_on_dbsc_session_id               (dbsc_session_id) UNIQUE
#  index_user_tokens_on_deletable_at                  (deletable_at)
#  index_user_tokens_on_device_id                     (device_id)
#  index_user_tokens_on_device_id_digest              (device_id_digest)
#  index_user_tokens_on_expired_at                    (expired_at)
#  index_user_tokens_on_public_id                     (public_id) UNIQUE
#  index_user_tokens_on_refresh_expires_at            (refresh_expires_at)
#  index_user_tokens_on_refresh_token_digest          (refresh_token_digest) UNIQUE
#  index_user_tokens_on_refresh_token_family_id       (refresh_token_family_id)
#  index_user_tokens_on_revoked_at                    (revoked_at)
#  index_user_tokens_on_status                        (status)
#  index_user_tokens_on_user_id_and_last_step_up_at   (user_id,last_step_up_at)
#  index_user_tokens_on_user_token_binding_method_id  (user_token_binding_method_id)
#  index_user_tokens_on_user_token_dbsc_status_id     (user_token_dbsc_status_id)
#  index_user_tokens_on_user_token_kind_id            (user_token_kind_id)
#  index_user_tokens_on_user_token_status_id          (user_token_status_id)
#
# Foreign Keys
#
#  fk_user_tokens_on_user_token_binding_method_id  (user_token_binding_method_id => user_token_binding_methods.id)
#  fk_user_tokens_on_user_token_dbsc_status_id     (user_token_dbsc_status_id => user_token_dbsc_statuses.id)
#  fk_user_tokens_on_user_token_kind_id            (user_token_kind_id => user_token_kinds.id)
#  fk_user_tokens_on_user_token_status_id          (user_token_status_id => user_token_statuses.id)
#

# Refresh tokens are persisted as digests only.
# The public_id is used as the session identifier (sid).
class UserToken < MarkRecord
  include ::PublicId
  include ::RefreshTokenable
  include ::SignedSessionReference
  include ::TokenDeletableSync
  include ::TokenStatusManagement
  include ::DbscBindable

  DBSC_BINDING_METHOD_CLASS = UserTokenBindingMethod
  DBSC_STATUS_CLASS = UserTokenDbscStatus

  MAX_SESSIONS_PER_USER = 2
  MAX_TOTAL_SESSIONS_PER_USER = 3

  belongs_to :user, inverse_of: :user_tokens
  belongs_to :user_token_status
  belongs_to :user_token_kind, optional: true
  belongs_to :user_token_binding_method
  belongs_to :user_token_dbsc_status
  has_many :user_verifications, dependent: :delete_all, inverse_of: :user_token
  attribute :user_token_status_id, default: UserTokenStatus::NOTHING
  attribute :user_token_kind_id, default: UserTokenKind::BROWSER_WEB
  attribute :user_token_binding_method_id, default: UserTokenBindingMethod::NOTHING
  attribute :user_token_dbsc_status_id, default: UserTokenDbscStatus::NOTHING

  validates :public_id, uniqueness: true, length: { maximum: 21 }
  validates :refresh_expires_at, presence: true

  validate :enforce_concurrent_session_limit, on: :create

  # This model-level validation provides an early, user-facing error message before
  # the database trigger rejects excess concurrent sessions.
  # The primary enforcement of the session limit is done by a database trigger,
  # which is more reliable and avoids race conditions.
  #
  # Note: We now allow up to 3 total sessions (2 active + 1 restricted),
  # but the Auth concern handles restricting the 3rd session.
  def enforce_concurrent_session_limit
    return unless user_id

    count = self.class.not_revoked.where(user_id: user_id, rotated_at: nil).count
    return if count < MAX_TOTAL_SESSIONS_PER_USER

    errors.add(
      :base, :too_many,
      message: "exceeds maximum concurrent sessions per user (#{MAX_TOTAL_SESSIONS_PER_USER})",
    )
  end
end

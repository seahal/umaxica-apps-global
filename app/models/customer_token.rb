# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_tokens
# Database name: symbol
#
#  id                               :bigint           not null, primary key
#  compromised_at                   :datetime
#  dbsc_challenge                   :text
#  dbsc_challenge_issued_at         :datetime
#  dbsc_public_key                  :jsonb
#  deletable_at                     :datetime         default(Infinity), not null
#  device_id_digest                 :string
#  expired_at                       :datetime
#  last_step_up_at                  :datetime
#  last_step_up_scope               :string
#  last_used_at                     :datetime
#  refresh_expires_at               :datetime         not null
#  refresh_token_digest             :binary
#  refresh_token_generation         :integer          default(0), not null
#  revoked_at                       :datetime
#  rotated_at                       :datetime
#  status                           :string(20)       default("active"), not null
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  customer_id                      :bigint           not null
#  customer_token_binding_method_id :bigint           default(0), not null
#  customer_token_dbsc_status_id    :bigint           default(0), not null
#  customer_token_kind_id           :bigint           default(1), not null
#  customer_token_status_id         :bigint           default(0), not null
#  dbsc_session_id                  :string
#  device_id                        :string           default(""), not null
#  public_id                        :string(21)       default(""), not null
#  refresh_token_family_id          :string
#
# Indexes
#
#  index_customer_tokens_on_compromised_at                    (compromised_at)
#  index_customer_tokens_on_customer_id_and_last_step_up_at   (customer_id,last_step_up_at)
#  index_customer_tokens_on_customer_token_binding_method_id  (customer_token_binding_method_id)
#  index_customer_tokens_on_customer_token_dbsc_status_id     (customer_token_dbsc_status_id)
#  index_customer_tokens_on_customer_token_kind_id            (customer_token_kind_id)
#  index_customer_tokens_on_customer_token_status_id          (customer_token_status_id)
#  index_customer_tokens_on_dbsc_session_id                   (dbsc_session_id) UNIQUE
#  index_customer_tokens_on_deletable_at                      (deletable_at)
#  index_customer_tokens_on_device_id                         (device_id)
#  index_customer_tokens_on_device_id_digest                  (device_id_digest)
#  index_customer_tokens_on_expired_at                        (expired_at)
#  index_customer_tokens_on_public_id                         (public_id) UNIQUE
#  index_customer_tokens_on_refresh_expires_at                (refresh_expires_at)
#  index_customer_tokens_on_refresh_token_digest              (refresh_token_digest) UNIQUE
#  index_customer_tokens_on_refresh_token_family_id           (refresh_token_family_id)
#  index_customer_tokens_on_revoked_at                        (revoked_at)
#  index_customer_tokens_on_status                            (status)
#
# Foreign Keys
#
#  fk_customer_tokens_on_customer_token_binding_method_id  (customer_token_binding_method_id => customer_token_binding_methods.id)
#  fk_customer_tokens_on_customer_token_dbsc_status_id     (customer_token_dbsc_status_id => customer_token_dbsc_statuses.id)
#  fk_customer_tokens_on_customer_token_kind_id            (customer_token_kind_id => customer_token_kinds.id)
#  fk_customer_tokens_on_customer_token_status_id          (customer_token_status_id => customer_token_statuses.id)
#
class CustomerToken < SymbolRecord
  include ::PublicId
  include ::RefreshTokenable
  include ::SignedSessionReference
  include ::TokenDeletableSync
  include ::TokenStatusManagement
  include ::DbscBindable

  DBSC_BINDING_METHOD_CLASS = CustomerTokenBindingMethod
  DBSC_STATUS_CLASS = CustomerTokenDbscStatus

  LOGIN_SESSION_TTL = 12.hours
  DELETION_GRACE_PERIOD = 1.day
  MAX_SESSIONS_PER_CUSTOMER = 1
  MAX_TOTAL_SESSIONS_PER_CUSTOMER = 2

  belongs_to :customer, inverse_of: :customer_tokens
  has_many :customer_verifications, dependent: :delete_all, inverse_of: :customer_token
  belongs_to :customer_token_status
  belongs_to :customer_token_kind, optional: true
  belongs_to :customer_token_binding_method
  belongs_to :customer_token_dbsc_status

  attribute :customer_token_status_id, default: CustomerTokenStatus::NOTHING
  attribute :customer_token_kind_id, default: CustomerTokenKind::BROWSER_WEB
  attribute :customer_token_binding_method_id, default: CustomerTokenBindingMethod::NOTHING
  attribute :customer_token_dbsc_status_id, default: CustomerTokenDbscStatus::NOTHING

  validates :public_id, uniqueness: true, length: { maximum: 21 }
  validates :refresh_expires_at, presence: true

  validate :enforce_concurrent_session_limit, on: :create

  def enforce_concurrent_session_limit
    return unless customer_id

    count = self.class.not_revoked.where(customer_id: customer_id, rotated_at: nil).count
    return if count < MAX_TOTAL_SESSIONS_PER_CUSTOMER

    errors.add(
      :base, :too_many,
      message: "exceeds maximum concurrent sessions per customer (#{MAX_TOTAL_SESSIONS_PER_CUSTOMER})",
    )
  end
end

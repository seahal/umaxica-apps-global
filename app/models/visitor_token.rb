# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_tokens
# Database name: symbol
#
#  id                              :bigint           not null, primary key
#  dbsc_challenge                  :text
#  dbsc_challenge_issued_at        :datetime
#  dbsc_public_key                 :jsonb
#  device_id_digest                :string
#  dpop_jkt                        :string
#  lapses_at                       :datetime         default(Infinity), not null
#  last_step_up_at                 :datetime
#  last_step_up_scope              :string
#  last_used_at                    :datetime
#  purge_at                        :datetime         default(Infinity), not null
#  refresh_token_digest            :binary
#  refresh_token_generation        :integer          default(0), not null
#  rotated_at                      :datetime
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  dbsc_session_id                 :string
#  device_id                       :string           default(""), not null
#  public_id                       :string(21)       default(""), not null
#  refresh_token_family_id         :string
#  session_id                      :string
#  visitor_id                      :bigint           not null
#  visitor_token_binding_method_id :bigint           default(0), not null
#  visitor_token_dbsc_status_id    :bigint           default(0), not null
#  visitor_token_kind_id           :bigint           default(1), not null
#  visitor_token_status_id         :bigint           default(1), not null
#
# Indexes
#
#  index_visitor_tokens_on_dbsc_session_id                  (dbsc_session_id) UNIQUE
#  index_visitor_tokens_on_device_id                        (device_id)
#  index_visitor_tokens_on_device_id_digest                 (device_id_digest)
#  index_visitor_tokens_on_public_id                        (public_id) UNIQUE
#  index_visitor_tokens_on_purge_at                         (purge_at)
#  index_visitor_tokens_on_refresh_token_digest             (refresh_token_digest) UNIQUE
#  index_visitor_tokens_on_refresh_token_family_id          (refresh_token_family_id)
#  index_visitor_tokens_on_session_id                       (session_id)
#  index_visitor_tokens_on_visitor_id_and_last_step_up_at   (visitor_id,last_step_up_at)
#  index_visitor_tokens_on_visitor_token_binding_method_id  (visitor_token_binding_method_id)
#  index_visitor_tokens_on_visitor_token_dbsc_status_id     (visitor_token_dbsc_status_id)
#  index_visitor_tokens_on_visitor_token_kind_id            (visitor_token_kind_id)
#  index_visitor_tokens_on_visitor_token_status_id          (visitor_token_status_id)
#
# Foreign Keys
#
#  fk_customer_tokens_on_customer_token_binding_method_id  (visitor_token_binding_method_id => visitor_token_binding_methods.id)
#  fk_customer_tokens_on_customer_token_dbsc_status_id     (visitor_token_dbsc_status_id => visitor_token_dbsc_statuses.id)
#  fk_customer_tokens_on_customer_token_kind_id            (visitor_token_kind_id => visitor_token_kinds.id)
#  fk_customer_tokens_on_customer_token_status_id          (visitor_token_status_id => visitor_token_statuses.id)
#
class VisitorToken < SymbolRecord
  include ::PublicId
  include ::RefreshTokenable
  include ::SignedSessionReference
  include ::Retainable
  include ::TokenStatusManagement
  include ::DbscBindable

  DBSC_BINDING_METHOD_CLASS = VisitorTokenBindingMethod
  DBSC_STATUS_CLASS = VisitorTokenDbscStatus

  LOGIN_SESSION_TTL = 12.hours
  DELETION_GRACE_PERIOD = 1.day
  MAX_SESSIONS_PER_VISITOR = 1
  MAX_TOTAL_SESSIONS_PER_VISITOR = 2

  belongs_to :visitor, inverse_of: :visitor_tokens
  has_many :visitor_verifications, dependent: :delete_all, inverse_of: :visitor_token
  belongs_to :visitor_token_status
  belongs_to :visitor_token_kind, optional: true
  belongs_to :visitor_token_binding_method
  belongs_to :visitor_token_dbsc_status
  has_one :reauth_session,
          class_name: "VisitorReauthSession",
          inverse_of: :visitor_token

  attribute :visitor_token_status_id, default: VisitorTokenStatus::ACTIVE
  attribute :visitor_token_kind_id, default: VisitorTokenKind::BROWSER_WEB
  attribute :visitor_token_binding_method_id, default: VisitorTokenBindingMethod::NOTHING
  attribute :visitor_token_dbsc_status_id, default: VisitorTokenDbscStatus::NOTHING

  validates :public_id, uniqueness: true, length: { maximum: 21 }

  before_create :ensure_session_id

  validate :enforce_concurrent_session_limit, on: :create
  attr_accessor :skip_session_limit_check

  private

  def ensure_session_id
    self.session_id = public_id if session_id.blank?
  end

  def enforce_concurrent_session_limit
    return if skip_session_limit_check
    return unless visitor_id

    operation = -> { self.class.not_revoked.where(visitor_id: visitor_id, rotated_at: nil).count }
    count = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    return if count < MAX_TOTAL_SESSIONS_PER_VISITOR

    errors.add(
      :base, :too_many,
      message: "exceeds maximum concurrent sessions per visitor (#{MAX_TOTAL_SESSIONS_PER_VISITOR})",
    )
  end
end

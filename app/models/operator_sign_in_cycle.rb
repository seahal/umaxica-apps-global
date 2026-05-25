# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_sign_in_cycles
# Database name: org_ticket
#
#  id           :bigint           not null, primary key
#  completed_at :datetime
#  discarded_at :datetime         default(Infinity), not null
#  expires_at   :datetime         not null
#  issued_at    :datetime         not null
#  nonce_digest :string           not null
#  purged_at    :datetime         default(Infinity), not null
#  return_to    :text
#  state        :string           not null
#  step         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  principal_id :bigint
#  public_id    :string(21)       not null
#  status_id    :bigint           default(10), not null
#  token_id     :bigint
#
# Indexes
#
#  index_operator_sign_in_cycles_on_discarded_at  (discarded_at)
#  index_operator_sign_in_cycles_on_expires_at    (expires_at)
#  index_operator_sign_in_cycles_on_principal_id  (principal_id)
#  index_operator_sign_in_cycles_on_public_id     (public_id) UNIQUE
#  index_operator_sign_in_cycles_on_state         (state)
#  index_operator_sign_in_cycles_on_status_id     (status_id)
#  index_operator_sign_in_cycles_on_token_id      (token_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => operator_sign_in_cycle_statuses.id)
#  fk_rails_...  (token_id => operator_tokens.id) ON DELETE => cascade
#
class OperatorSignInCycle < OrgTicketRecord
  include SignCycle
  include Cycle::SignIn

  STATUS_MODEL = OperatorSignInCycleStatus
  STATUSES = {
    "PRIMARY_PENDING" => STATUS_MODEL::PRIMARY_PENDING,
    "MFA_PENDING" => STATUS_MODEL::MFA_PENDING,
    "SESSION_LIMIT_PENDING" => STATUS_MODEL::SESSION_LIMIT_PENDING,
    "GUARDRAIL_PENDING" => STATUS_MODEL::GUARDRAIL_PENDING,
    "SESSION_ISSUANCE_PENDING" => STATUS_MODEL::SESSION_ISSUANCE_PENDING,
    "CHECKPOINT_PENDING" => STATUS_MODEL::CHECKPOINT_PENDING,
    "SELECTOR_PENDING" => STATUS_MODEL::SELECTOR_PENDING,
    "DASHBOARD_PENDING" => STATUS_MODEL::DASHBOARD_PENDING,
    "RETURN_PENDING" => STATUS_MODEL::RETURN_PENDING,
    "COMPLETED" => STATUS_MODEL::COMPLETED,
    "FAILED" => STATUS_MODEL::FAILED,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze
  STEPS = %w(primary mfa session_limit guardrail checkpoint selector session_issuance dashboard return_to completed
             failed).freeze
  TRANSITIONS = {
    STATUS_MODEL::PRIMARY_PENDING => [
      STATUS_MODEL::MFA_PENDING,
      STATUS_MODEL::SESSION_LIMIT_PENDING,
      STATUS_MODEL::GUARDRAIL_PENDING,
      STATUS_MODEL::FAILED,
    ],
    STATUS_MODEL::MFA_PENDING => [
      STATUS_MODEL::SESSION_LIMIT_PENDING,
      STATUS_MODEL::GUARDRAIL_PENDING,
      STATUS_MODEL::FAILED,
    ],
    STATUS_MODEL::SESSION_LIMIT_PENDING => [STATUS_MODEL::GUARDRAIL_PENDING, STATUS_MODEL::FAILED],
    STATUS_MODEL::GUARDRAIL_PENDING => [STATUS_MODEL::CHECKPOINT_PENDING, STATUS_MODEL::FAILED],
    STATUS_MODEL::CHECKPOINT_PENDING => [STATUS_MODEL::SELECTOR_PENDING, STATUS_MODEL::FAILED],
    STATUS_MODEL::SELECTOR_PENDING => [STATUS_MODEL::SESSION_ISSUANCE_PENDING, STATUS_MODEL::FAILED],
    STATUS_MODEL::SESSION_ISSUANCE_PENDING => [STATUS_MODEL::COMPLETED, STATUS_MODEL::FAILED],
    STATUS_MODEL::DASHBOARD_PENDING => [STATUS_MODEL::RETURN_PENDING, STATUS_MODEL::FAILED],
    STATUS_MODEL::RETURN_PENDING => [STATUS_MODEL::COMPLETED, STATUS_MODEL::FAILED],
    STATUS_MODEL::COMPLETED => [],
    STATUS_MODEL::FAILED => [],
  }.freeze

  belongs_to :token, class_name: "OperatorToken"
  belongs_to :status, class_name: "OperatorSignInCycleStatus"
end

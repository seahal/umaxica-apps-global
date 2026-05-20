# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_withdrawal_cycle_events
# Database name: app_principal
#
#  id                         :bigint           not null, primary key
#  metadata                   :jsonb            not null
#  occurred_at                :datetime         not null
#  reason                     :string(64)       default(""), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  client_id                  :bigint           not null
#  client_withdrawal_cycle_id :bigint           not null
#  from_status_id             :bigint
#  to_status_id               :bigint           not null
#  token_public_id            :string(64)       default(""), not null
#
# Indexes
#
#  idx_on_client_withdrawal_cycle_id_f40263c70b            (client_withdrawal_cycle_id)
#  index_client_withdrawal_cycle_events_on_client_id       (client_id)
#  index_client_withdrawal_cycle_events_on_from_status_id  (from_status_id)
#  index_client_withdrawal_cycle_events_on_occurred_at     (occurred_at)
#  index_client_withdrawal_cycle_events_on_to_status_id    (to_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => users.id)
#  fk_rails_...  (client_withdrawal_cycle_id => client_withdrawal_cycles.id)
#  fk_rails_...  (from_status_id => client_withdrawal_cycle_statuses.id)
#  fk_rails_...  (to_status_id => client_withdrawal_cycle_statuses.id)
#
class ClientWithdrawalCycleEvent < AppPrincipalRecord
  belongs_to :client_withdrawal_cycle,
             inverse_of: :client_withdrawal_cycle_events
  belongs_to :client,
             class_name: "Client"
  belongs_to :from_status,
             class_name: "ClientWithdrawalCycleStatus"
  belongs_to :to_status,
             class_name: "ClientWithdrawalCycleStatus"

  before_validation :ensure_withdrawal_cycle_status_defaults

  validates :from_status_id, inclusion: { in: ClientWithdrawalCycleStatus::DEFAULTS }, allow_nil: true
  validates :to_status_id, inclusion: { in: ClientWithdrawalCycleStatus::DEFAULTS }
  validates :occurred_at, presence: true
  validates :token_public_id, length: { maximum: 64 }, allow_blank: true
  validates :reason, length: { maximum: 64 }, allow_blank: true

  private

  def ensure_withdrawal_cycle_status_defaults
    ClientWithdrawalCycleStatus.ensure_defaults!
  end
end

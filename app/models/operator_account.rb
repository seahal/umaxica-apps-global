# typed: false
# == Schema Information
#
# Table name: operator_accounts
# Database name: operator
#
#  id            :bigint           not null, primary key
#  lock_version  :integer          default(0), not null
#  moniker       :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  department_id :bigint
#  public_id     :string           not null
#  staff_id      :bigint           not null
#  status_id     :bigint           default(2), not null
#
# Indexes
#
#  index_operator_accounts_on_department_id  (department_id)
#  index_operator_accounts_on_public_id      (public_id) UNIQUE
#  index_operator_accounts_on_staff_id       (staff_id)
#  index_operator_accounts_on_status_id      (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (department_id => departments.id) ON DELETE => nullify
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (status_id => operator_statuses.id)
#

# frozen_string_literal: true

class OperatorAccount < OperatorRecord
  include Retainable
  include ::Account

  attribute :status_id, default: OperatorStatus::NOTHING

  belongs_to :operator_status,
             foreign_key: :status_id,
             inverse_of: :operator_accounts
  belongs_to :operator,
             class_name: "Operator",
             foreign_key: :staff_id,
             inverse_of: :operator_accounts
  belongs_to :staff,
             class_name: "Operator",
             inverse_of: false
  belongs_to :department, optional: true, inverse_of: :operator_accounts
  has_many :staff_operators, class_name: "OperatorAccountMembership", dependent: :destroy,
                             foreign_key: :operator_id,
                             inverse_of: :operator_account
  has_many :operators,
           through: :staff_operators,
           source: :staff
end

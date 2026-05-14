# typed: false
# == Schema Information
#
# Table name: staff_operators
# Database name: operator
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  operator_id :bigint           not null
#  staff_id    :bigint           not null
#
# Indexes
#
#  index_staff_operators_on_operator_id               (operator_id)
#  index_staff_operators_on_staff_id_and_operator_id  (staff_id,operator_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (operator_id => operator_accounts.id) ON DELETE => cascade
#  fk_rails_...  (staff_id => operators.id) ON DELETE => cascade
#

# frozen_string_literal: true

class OperatorAccountMembership < OperatorRecord
  self.table_name = "staff_operators"
  belongs_to :staff,
             class_name: "Operator",
             inverse_of: :staff_operators
  belongs_to :operator_account,
             class_name: "OperatorAccount",
             foreign_key: :operator_id,
             inverse_of: :staff_operators

  validates :operator_id, uniqueness: { scope: :staff_id }
end

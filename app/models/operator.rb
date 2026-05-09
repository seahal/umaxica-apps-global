# typed: false
# == Schema Information
#
# Table name: operators
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
#  index_operators_on_department_id  (department_id)
#  index_operators_on_public_id      (public_id) UNIQUE
#  index_operators_on_staff_id       (staff_id)
#  index_operators_on_status_id      (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (department_id => departments.id) ON DELETE => nullify
#  fk_rails_...  (staff_id => staffs.id)
#  fk_rails_...  (status_id => operator_statuses.id)
#

# frozen_string_literal: true

class Operator < OperatorRecord
  include Retainable
  include ::Account

  attribute :status_id, default: OperatorStatus::NOTHING

  belongs_to :operator_status,
             foreign_key: :status_id,
             inverse_of: :operators
  belongs_to :staff, inverse_of: :operators
  belongs_to :department, optional: true, inverse_of: :operators
  has_many :staff_operators,
           dependent: :destroy,
           inverse_of: :operator
  has_many :staffs,
           through: :staff_operators
end

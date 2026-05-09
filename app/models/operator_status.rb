# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_statuses
# Database name: operator
#
#  id :bigint           not null, primary key
#
class OperatorStatus < OperatorRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  ACTIVE = 1
  NOTHING = 2
  has_many :operators,
           foreign_key: :status_id,
           inverse_of: :operator_status,
           dependent: :restrict_with_error
end

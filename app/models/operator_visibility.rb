# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_visibilities
# Database name: operator
#
#  id :bigint           not null, primary key
#
class OperatorVisibility < OperatorRecord
  self.table_name = "staff_visibilities"
  include ReferenceRecord

  NOBODY = 0
  USER = 1
  STAFF = 2
  BOTH = 3

  DEFAULTS = [NOBODY, USER, STAFF, BOTH].freeze

  has_many :staffs,
           class_name: "Operator",
           foreign_key: :visibility_id,
           dependent: :restrict_with_error,
           inverse_of: :visibility
end

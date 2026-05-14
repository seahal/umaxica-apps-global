# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_secret_kinds
# Database name: operator
#
#  id :bigint           not null, primary key
#

class OperatorSecretKind < OperatorRecord
  self.table_name = "staff_secret_kinds"
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 1
  LOGIN = 2
  PERMANENT = LOGIN
  ONE_TIME = NOTHING

  # Kind constants
  ALL = [LOGIN].freeze
  ALLOWED_FOR_SECRET_SIGN_IN = [PERMANENT].freeze

  has_many :staff_secrets, class_name: "OperatorSecret", inverse_of: :staff_secret_kind,
                           dependent: :restrict_with_exception

  validates :id, uniqueness: true
end

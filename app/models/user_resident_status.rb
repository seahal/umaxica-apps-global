# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_resident_statuses
# Database name: resident
#
#  id :bigint           not null, primary key
#
class UserResidentStatus < ResidentRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  SUSPENDED = 2
  DELETED = 3
  DEFAULTS = [NOTHING, ACTIVE, SUSPENDED, DELETED].freeze

  has_many :user_residents,
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :user_resident_status
end

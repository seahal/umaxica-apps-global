# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_preference_dbsc_statuses
# Database name: operator
#
#  id :bigint           not null, primary key
#
class OrgPreferenceDbscStatus < OperatorRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  PENDING = 2
  FAILED = 3
  REVOKE = 4
  DEFAULTS = [NOTHING, ACTIVE, PENDING, FAILED, REVOKE].freeze

  has_many :org_preferences,
           foreign_key: :dbsc_status_id,
           inverse_of: :org_preference_dbsc_status,
           dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end

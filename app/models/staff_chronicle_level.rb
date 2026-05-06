# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#

class StaffChronicleLevel < ChronicleRecord
  # Fixed IDs - do not modify these values
  NOTHING = 1
  has_many :staff_chronicles,
           foreign_key: :level_id,
           dependent: :restrict_with_error,
           inverse_of: :staff_chronicle_level
end

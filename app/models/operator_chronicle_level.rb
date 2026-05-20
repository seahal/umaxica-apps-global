# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#

class OperatorChronicleLevel < ChronicleRecord
  self.table_name = "staff_chronicle_levels"
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 1
  DEFAULTS = [NOTHING].freeze
  has_many :staff_chronicles, class_name: "OperatorChronicle", foreign_key: :level_id,
                              dependent: :restrict_with_error,
                              inverse_of: :staff_chronicle_level
end

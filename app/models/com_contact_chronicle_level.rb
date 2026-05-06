# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_contact_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class ComContactChronicleLevel < ChronicleRecord
  self.record_timestamps = false

  NOTHING = 1
  DEBUG = 2
  INFO = 3
  WARN = 4
  ERROR = 5

  has_many :com_contact_chronicles, dependent: :restrict_with_error, inverse_of: :com_contact_chronicle_level
end

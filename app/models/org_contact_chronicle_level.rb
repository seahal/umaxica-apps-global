# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: org_contact_chronicle_levels
# Database name: chronicle
#
#  id :bigint           not null, primary key
#
class OrgContactChronicleLevel < ChronicleRecord
  include ReferenceRecord

  NOTHING = 1
  DEBUG = 2
  INFO = 3
  WARN = 4
  ERROR = 5

  has_many :org_contact_chronicles, dependent: :restrict_with_error, inverse_of: :org_contact_chronicle_level
end

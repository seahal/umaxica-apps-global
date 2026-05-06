# typed: false
# == Schema Information
#
# Table name: org_preference_colortheme_options
# Database name: operator
#
#  id :bigint           not null, primary key
#

# frozen_string_literal: true

class OrgPreferenceColorthemeOption < OperatorRecord
  # Fixed IDs - do not modify these values
  LIGHT = 1
  DARK = 2
  SYSTEM = 3

  has_many :org_preference_colorthemes,
           class_name: "OrgPreferenceColortheme",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def name
    case id
    when LIGHT then "light"
    when DARK then "dark"
    when SYSTEM then "system"
    end
  end

  DEFAULTS = [LIGHT, DARK, SYSTEM].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end

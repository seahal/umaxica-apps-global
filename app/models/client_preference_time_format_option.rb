# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preference_time_format_options
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientPreferenceTimeFormatOption < AppPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  HOUR_24 = 1
  HOUR_12 = 2

  has_many :client_preference_time_formats,
           class_name: "ClientPreferenceTimeFormat",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def name
    case id
    when 1 then "hour_24"
    when 2 then "hour_12"
    end
  end

  DEFAULTS = [NOTHING, HOUR_24, HOUR_12].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end

# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_preference_items_per_page_options
# Database name: com_setting
#
#  id :bigint           not null, primary key
#
class ComPreferenceItemsPerPageOption < ComSettingRecord
  include ReferenceRecord

  NOTHING = 0
  PER_10 = 1
  PER_20 = 2
  PER_50 = 3
  PER_100 = 4
  PER_INFINITY = 5

  has_many :com_preference_items_per_pages,
           class_name: "ComPreferenceItemsPerPage",
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def name
    case id
    when 1 then "10"
    when 2 then "20"
    when 3 then "50"
    when 4 then "100"
    when 5 then "infinity"
    end
  end

  DEFAULTS = [NOTHING, PER_10, PER_20, PER_50, PER_100, PER_INFINITY].freeze

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end

# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: app_preference_r18_display_stopper_options
# Database name: app_setting
#
#  id :bigint           not null, primary key
#
class AppPreferenceR18DisplayStopperOption < AppSettingRecord
  include ReferenceRecord

  NOTHING = 0
  APPROVED = 1
  DENY = 2
  DEFAULTS = [NOTHING, APPROVED, DENY].freeze

  has_many :app_preference_r18_display_stoppers,
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def name
    case id
    when NOTHING then "nothing"
    when APPROVED then "approved"
    when DENY then "deny"
    end
  end

  def approved? = id == APPROVED

  def denied? = id == DENY

  def enabled? = denied?

  def self.ensure_defaults! = insert_missing_fixed_ids!(DEFAULTS)
end

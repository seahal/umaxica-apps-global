# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_preference_r18_display_stopper_options
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
class VisitorPreferenceR18DisplayStopperOption < ComPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  APPROVED = 1
  DENY = 2
  DEFAULTS = [NOTHING, APPROVED, DENY].freeze

  has_many :visitor_preference_r18_display_stoppers,
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

# typed: false
# frozen_string_literal: true

class Sign::Com::Preference::Region::TimeFormatsController < Sign::Com::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :time_format
end

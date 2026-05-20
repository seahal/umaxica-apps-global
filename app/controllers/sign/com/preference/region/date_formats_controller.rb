# typed: false
# frozen_string_literal: true

class Sign::Com::Preference::Region::DateFormatsController < Sign::Com::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :date_format
end

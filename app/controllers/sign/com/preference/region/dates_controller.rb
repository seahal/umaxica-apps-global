# typed: false
# frozen_string_literal: true

class Sign::Com::Preference::Region::DatesController < Sign::Com::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :date_format
end

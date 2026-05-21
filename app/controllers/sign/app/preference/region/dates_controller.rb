# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Region::DatesController < Sign::App::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :date_format
end

# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Region::TimeFormatsController < Sign::App::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :time_format
end

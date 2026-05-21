# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Region::TimesController < Sign::App::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :time_format
end

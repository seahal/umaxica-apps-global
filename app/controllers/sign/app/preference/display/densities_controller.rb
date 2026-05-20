# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Display::DensitiesController < Sign::App::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :density
end

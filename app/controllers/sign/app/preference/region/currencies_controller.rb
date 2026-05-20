# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Region::CurrenciesController < Sign::App::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :currency
end

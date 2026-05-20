# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::Region::CurrenciesController < Sign::Org::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :currency
end

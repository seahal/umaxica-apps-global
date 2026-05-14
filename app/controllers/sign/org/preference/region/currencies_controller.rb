# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::Region::CurrenciesController < Sign::Org::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :currency
end

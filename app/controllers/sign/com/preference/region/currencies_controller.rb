# typed: false
# frozen_string_literal: true

class Sign::Com::Preference::Region::CurrenciesController < Sign::Com::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :currency
end

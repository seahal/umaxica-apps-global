# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Region::CurrenciesController < Sign::App::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :currency
end

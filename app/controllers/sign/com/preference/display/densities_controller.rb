# typed: false
# frozen_string_literal: true

class Sign::Com::Preference::Display::DensitiesController < Sign::Com::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :density
end

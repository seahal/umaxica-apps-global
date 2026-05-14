# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Display::DensitiesController < Sign::App::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :density
end

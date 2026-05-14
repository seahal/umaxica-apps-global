# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::Display::DensitiesController < Sign::Org::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :density
end

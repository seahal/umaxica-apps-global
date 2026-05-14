# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Region::TimeFormatsController < Sign::App::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :time_format
end

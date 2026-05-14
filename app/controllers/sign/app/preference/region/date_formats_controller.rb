# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Region::DateFormatsController < Sign::App::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :date_format
end

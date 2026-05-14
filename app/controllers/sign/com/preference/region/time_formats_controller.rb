# typed: false
# frozen_string_literal: true

class Sign::Com::Preference::Region::TimeFormatsController < Sign::Com::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :time_format
end

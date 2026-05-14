# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::Region::TimeFormatsController < Sign::Org::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :time_format
end

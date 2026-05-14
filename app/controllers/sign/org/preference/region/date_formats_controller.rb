# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::Region::DateFormatsController < Sign::Org::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :date_format
end

# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::Display::ItemsPerPagesController < Sign::Org::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :items_per_page
end

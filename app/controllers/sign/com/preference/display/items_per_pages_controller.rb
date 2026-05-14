# typed: false
# frozen_string_literal: true

class Sign::Com::Preference::Display::ItemsPerPagesController < Sign::Com::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :items_per_page
end

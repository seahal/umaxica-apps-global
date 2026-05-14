# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Display::ItemsPerPagesController < Sign::App::ApplicationController
  public_strict!
  include ::Preference::SignScreenActions

  preference_screen :items_per_page
end

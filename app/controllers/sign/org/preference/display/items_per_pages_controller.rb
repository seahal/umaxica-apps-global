# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::Display::ItemsPerPagesController < Sign::Org::PreferencesBaseController
  include ::Preference::SignScreenActions

  preference_screen :items_per_page
end

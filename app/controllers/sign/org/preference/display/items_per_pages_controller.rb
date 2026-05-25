# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::Display::ItemsPerPagesController < Sign::Org::PreferencesBaseController
  AUTHENTICATION_MODE = :open

  include ::Preference::SignScreenActions

  before_action :ensure_preferences_record

  def edit
    edit_selectable_preference_screen(:items_per_page)
  end

  def update
    update_selectable_preference_screen(:items_per_page)
  end
end

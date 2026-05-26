# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Display::R18DisplayStoppersController < Sign::App::PreferencesBaseController
  include ::Preference::SignScreenActions

  AUTHENTICATION_MODE = :open

  before_action :ensure_preferences_record

  def edit
    edit_selectable_preference_screen(:r18_display_stopper)
  end

  def update
    update_selectable_preference_screen(:r18_display_stopper)
  end
end

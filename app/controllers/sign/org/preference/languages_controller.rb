# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::LanguagesController < Sign::Org::PreferencesBaseController
  include ::Preference::SignScreenActions

  AUTHENTICATION_MODE = :open

  before_action :ensure_preferences_record

  def edit
    edit_language_preference_screen
  end

  def update
    update_language_preference_screen
  end
end

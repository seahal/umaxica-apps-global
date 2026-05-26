# typed: false
# frozen_string_literal: true

class Sign::Com::Preference::Accessibility::MotionsController < Sign::Com::PreferencesBaseController
  include ::Preference::SignScreenActions

  AUTHENTICATION_MODE = :open

  before_action :ensure_preferences_record

  def edit
    edit_selectable_preference_screen(:motion)
  end

  def update
    update_selectable_preference_screen(:motion)
  end
end

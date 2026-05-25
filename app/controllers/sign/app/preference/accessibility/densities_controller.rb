# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Accessibility::DensitiesController < Sign::App::PreferencesBaseController
  AUTHENTICATION_MODE = :open

  include ::Preference::SignScreenActions

  before_action :ensure_preferences_record

  def edit
    edit_selectable_preference_screen(:density)
  end

  def update
    update_selectable_preference_screen(:density)
  end
end

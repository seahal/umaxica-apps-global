# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::DatesController < Sign::Org::PreferencesBaseController
  include ::Preference::SignScreenActions

  AUTHENTICATION_MODE = :open

  before_action :ensure_preferences_record

  def edit
    edit_selectable_preference_screen(:date_format)
  end

  def update
    update_selectable_preference_screen(:date_format)
  end
end

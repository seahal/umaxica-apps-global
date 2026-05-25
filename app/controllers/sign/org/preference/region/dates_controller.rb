# typed: false
# frozen_string_literal: true

class Sign::Org::Preference::Region::DatesController < Sign::Org::PreferencesBaseController
  AUTHENTICATION_MODE = :open

  include ::Preference::SignScreenActions

  before_action :ensure_preferences_record

  def edit
    edit_selectable_preference_screen(:date_format)
  end

  def update
    update_selectable_preference_screen(:date_format)
  end
end

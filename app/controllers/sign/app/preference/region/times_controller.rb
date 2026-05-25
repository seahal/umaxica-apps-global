# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Region::TimesController < Sign::App::PreferencesBaseController
  include ::Preference::SignScreenActions

  before_action :ensure_preferences_record

  def edit
    edit_selectable_preference_screen(:time_format)
  end

  def update
    update_selectable_preference_screen(:time_format)
  end
end

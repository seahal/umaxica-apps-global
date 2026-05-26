# typed: false
# frozen_string_literal: true

class Sign::App::Preference::Region::CurrenciesController < Sign::App::PreferencesBaseController
  include ::Preference::SignScreenActions

  AUTHENTICATION_MODE = :open

  before_action :ensure_preferences_record

  def edit
    edit_selectable_preference_screen(:currency)
  end

  def update
    update_selectable_preference_screen(:currency)
  end
end

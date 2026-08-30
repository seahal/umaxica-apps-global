# typed: false
# frozen_string_literal: true

module PreferenceLocalization
  extend ActiveSupport::Concern

  private

  # Locale only. The request time zone is owned by PreferenceGlobal#set_timezone,
  # which layers the request overlay and preference cookie on top of the actor
  # record; assigning Time.zone here too would let the narrower source win.
  def apply_localization_preferences
    I18n.locale = localization_locale
  rescue ArgumentError
    I18n.locale = I18n.default_locale
  end

  def localization_locale
    preference = Actor.preferences if defined?(Actor)
    locale = preference&.language
    locale.presence || I18n.default_locale
  end
end

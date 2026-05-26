# typed: false
# frozen_string_literal: true

module Preference::Localization
  extend ActiveSupport::Concern

  private

  def apply_localization_preferences
    I18n.locale = localization_locale
    Time.zone = localization_timezone
  rescue ArgumentError
    I18n.locale = I18n.default_locale
    Time.zone = "Etc/UTC"
  end

  def localization_locale
    preference = Actor.preferences if defined?(Actor)
    locale = preference&.language
    locale.presence || I18n.default_locale
  end

  def localization_timezone
    preference = Actor.preferences if defined?(Actor)
    timezone = preference&.timezone

    case timezone.to_s.downcase
    when "jst"
      "Asia/Tokyo"
    when "utc", "etc/utc"
      "Etc/UTC"
    else
      timezone.presence || "Asia/Tokyo"
    end
  end
end

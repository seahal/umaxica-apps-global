# typed: false
# frozen_string_literal: true

module Preference::Localization
  extend ActiveSupport::Concern

  included do
    before_action :apply_localization_preferences
  end

  private

  def apply_localization_preferences
    I18n.locale = localization_locale
    Time.zone = localization_timezone
  rescue ArgumentError
    I18n.locale = I18n.default_locale
    Time.zone = "Etc/UTC"
  end

  def localization_locale
    locale =
      if respond_to?(:effective_context)
        effective_context[:lx]
      else
        params[:lx].presence || cookies[Preference::Base::LANGUAGE_COOKIE_KEY].presence
      end

    locale.presence || I18n.default_locale
  end

  def localization_timezone
    timezone =
      if params[:tz].present?
        params[:tz]
      elsif session[:timezone].present?
        session[:timezone]
      elsif respond_to?(:effective_context)
        effective_context[:tz]
      else
        cookies[Preference::Base::TIMEZONE_COOKIE_KEY].presence
      end

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

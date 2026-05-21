# typed: false
# frozen_string_literal: true

module Sign::CommonHelper
  def to_localetime(time, tz = "utc")
    return nil if time.nil?

    zone =
      case tz.to_s.downcase
      when "jst"
        "Asia/Tokyo"
      else
        "UTC"
      end

    time.in_time_zone(zone)
  end

  def get_timezone
    "jst"
  end

  def get_language
    I18n.locale.to_s.start_with?("en") ? "en" : "ja"
  end

  def get_region
    "jp"
  end

  def get_theme
    "sy"
  end

  def preference_language_options(option_class)
    option_class.order(:id).filter_map do |option|
      label =
        case option.name
        when "ja" then t("languages.japanese")
        when "en" then t("languages.english")
        end
      [label, option.id] if label.present?
    end
  end

  def preference_language_selected(option_id, option_class)
    return option_id if option_id.present?

    I18n.locale.to_s.start_with?("en") ? option_class::EN : option_class::JA
  end

  def localized_session_timestamp(time)
    return nil if time.nil?

    short_format = I18n.t("time.formats.short")
    format_string = short_format.presence || "%Y/%m/%d %H:%M"
    time.utc.strftime(format_string)
  end
end

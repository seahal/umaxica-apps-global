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
    "ja"
  end

  def get_region
    "jp"
  end

  def get_theme
    "sy"
  end

  def localized_session_timestamp(time)
    return nil if time.nil?

    short_format = I18n.t("time.formats.short")
    format_string = short_format.presence || "%Y/%m/%d %H:%M"
    time.strftime(format_string)
  end
end

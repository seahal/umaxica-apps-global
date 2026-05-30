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

  def sign_up_birthdate_fields(value, labelledby: nil)
    format = sign_up_birthdate_date_format
    parts = sign_up_birthdate_value_parts(value)
    order = sign_up_birthdate_part_order(format)

    content_tag(:div, role: "group", aria: { labelledby: labelledby }, data: { birthdate_format: format }) do
      safe_join(
        order.map { |part| sign_up_birthdate_part_field(part, parts[part]) },
        sign_up_birthdate_separator(format),
      )
    end
  end

  def sign_up_birthdate_date_format
    value = Actor.preferences.date_format if defined?(Actor)
    normalized = value.to_s.downcase
    return "us" if normalized == "us"
    return "uk" if normalized == "uk"

    "iso"
  end

  def sign_up_birthdate_part_order(format = sign_up_birthdate_date_format)
    case format.to_s
    when "us"
      %w(month day year)
    when "uk"
      %w(day month year)
    else
      %w(year month day)
    end
  end

  private

  def sign_up_birthdate_value_parts(value)
    match = /\A(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})\z/.match(value.to_s)
    return { "year" => nil, "month" => nil, "day" => nil } unless match

    {
      "year" => match[:year],
      "month" => match[:month],
      "day" => match[:day],
    }
  end

  def sign_up_birthdate_part_field(part, value)
    content_tag(:label, for: "birthdate_#{part}") do
      safe_join(
        [
          sign_up_birthdate_part_label(part),
          number_field_tag(
            "birthdate_#{part}",
            value,
            id: "birthdate_#{part}",
            required: true,
            autocomplete: "bday-#{part}",
            inputmode: "numeric",
            min: sign_up_birthdate_part_min(part),
            max: sign_up_birthdate_part_max(part),
            placeholder: sign_up_birthdate_part_placeholder(part),
            data: { birthdate_part: part },
          ),
        ],
        " ",
      )
    end
  end

  def sign_up_birthdate_part_label(part)
    case part
    when "year" then "YYYY"
    when "month" then "MM"
    else "DD"
    end
  end

  def sign_up_birthdate_part_placeholder(part)
    sign_up_birthdate_part_label(part)
  end

  def sign_up_birthdate_part_min(part)
    case part
    when "year" then 1900
    else 1
    end
  end

  def sign_up_birthdate_part_max(part)
    case part
    when "year" then Time.zone.today.year
    when "month" then 12
    else 31
    end
  end

  def sign_up_birthdate_separator(format)
    case format.to_s
    when "us", "uk" then " / "
    else " - "
    end
  end
end

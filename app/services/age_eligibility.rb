# typed: false
# frozen_string_literal: true

module AgeEligibility
  module_function

  def birthdate_for_age(value)
    return nil if value.blank?

    birthdate = value.to_s
    return nil unless birthdate.match?(Jit::Utils::BirthdateFormat::PATTERN)

    year, month, day = birthdate.split("-").map(&:to_i)
    Date.new(year, month, day)
  rescue Date::Error
    Date.new(year, month, 1).next_month
  end

  def minimum_age_reached?(birthdate, minimum_age:, today: Time.zone.today)
    age_birthdate = birthdate_for_age(birthdate)
    return false unless age_birthdate

    today.to_date >= age_birthdate.advance(years: minimum_age)
  end
end

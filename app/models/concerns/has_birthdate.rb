# typed: false
# frozen_string_literal: true

module HasBirthdate
  extend ActiveSupport::Concern

  BIRTHDATE_FORMAT = /\A\d{4}-\d{2}-\d{2}\z/

  included do
    encrypts :birthdate

    validates :birthdate, length: { maximum: 10 }, allow_blank: true

    validate :birthdate_format
    validate :birthdate_not_future
  end

  def parsed_birthdate
    return nil if birthdate.blank?

    Date.iso8601(birthdate)
  rescue Date::Error
    nil
  end

  def calendar_valid_birthdate?
    parsed_birthdate.present?
  end

  def age_on(date = Time.zone.today)
    date = date.to_date
    bday = parsed_birthdate
    return nil unless bday

    age = date.year - bday.year
    before_birthday = ([date.month, date.day] <=> [bday.month, bday.day]).negative?

    before_birthday ? age - 1 : age
  end

  def adult_for_nsfw?(minimum_age: 18, today: Time.zone.today)
    age = age_on(today)

    age.present? && age >= minimum_age
  end

  def nsfw_unlockable?
    birthdate.present? && calendar_valid_birthdate? && adult_for_nsfw?
  end

  private

  def birthdate_format
    return if birthdate.blank?
    return if birthdate.match?(BIRTHDATE_FORMAT)

    errors.add(:birthdate, "must be in YYYY-MM-DD format")
  end

  def birthdate_not_future
    return if birthdate.blank?
    return unless birthdate.match?(BIRTHDATE_FORMAT)

    today = Time.zone.today.strftime("%Y-%m-%d")
    errors.add(:birthdate, "must not be in the future") if birthdate > today
  end
end

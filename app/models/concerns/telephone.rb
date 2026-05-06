# typed: false
# frozen_string_literal: true

module Telephone
  extend ActiveSupport::Concern
  include TelephoneNormalization

  attr_accessor :confirm_policy, :confirm_using_mfa, :pass_code
  attr_writer :raw_number

  included do
    before_validation :normalize_number_from_raw

    after_initialize do
      self.otp_counter = "0" if otp_counter.blank?
      self.otp_private_key = ROTP::Base32.random_base32 if otp_private_key.blank?
      self.otp_attempts_count ||= 0
    end

    encrypts :number, deterministic: true

    validate :validate_telephone_number

    validates :confirm_policy, acceptance: true,
                               unless: Proc.new { |a| a.raw_number.blank? && a.pass_code.present? }
    validates :confirm_using_mfa, acceptance: true,
                                  unless: Proc.new { |a| a.raw_number.blank? && a.pass_code.present? }
    validates :pass_code, numericality: { only_integer: true },
                          length: { is: 6 },
                          presence: true,
                          unless: Proc.new { |a| a.pass_code.blank? && a.raw_number.present? }
  end

  # OTP-related methods for telephone authentication
  # Stores OTP secret on this telephone record
  def store_otp(otp_private_key, otp_counter, expires_at)
    update!(
      otp_private_key: otp_private_key,
      otp_counter: otp_counter,
      otp_expires_at: Time.zone.at(expires_at),
      otp_attempts_count: 0,
      locked_at: "-infinity",
    )
  end

  # Retrieves OTP secret from this telephone record
  def get_otp
    return nil if otp_private_key.blank? || otp_expired? || locked?

    {
      otp_private_key: otp_private_key,
      otp_counter: Integer(otp_counter.to_s, 10),
      otp_expires_at: otp_expires_at.to_i,
    }
  end

  # Clears OTP secret after verification
  def clear_otp
    update!(
      otp_counter: "0",
      otp_expires_at: "-infinity",
      otp_attempts_count: 0,
      locked_at: "-infinity",
    )
  end

  # Checks if OTP has expired
  def otp_expired?
    # PostgreSQL -infinity is used as a sentinel for "never expires"
    return true if otp_expires_at.is_a?(Float) && otp_expires_at == -Float::INFINITY

    otp_expires_at.nil? || otp_expires_at <= Time.current
  end

  # Checks if OTP is still active
  def otp_active?
    !otp_expired? && !locked?
  end

  def locked?
    # PostgreSQL -infinity is used as a sentinel for "not locked"
    is_locked_by_time = locked_at.present? && locked_at != -Float::INFINITY
    is_locked_by_attempts = otp_attempts_count >= 3
    is_locked_by_time || is_locked_by_attempts
  end

  def increment_attempts!
    # rubocop:disable Rails/SkipsModelValidations
    increment!(:otp_attempts_count)
    # Conditionally set locked_at when threshold is reached and not already locked
    # Threshold is 3 (see locked? method)
    self.class
      .where(id: id)
      .where(otp_attempts_count: 3..)
      .where("locked_at IS NULL OR locked_at = '-infinity'::timestamp")
      .update_all(locked_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
    reload if locked_at_changed?
  end

  def raw_number
    @raw_number.presence || number
  end

  private

  def normalize_number_from_raw
    value = raw_number
    return if value.blank?

    normalized = TelephoneNormalization.normalize_to_e164(value)
    self.number = normalized if normalized.present?
  end

  def validate_telephone_number
    return if raw_number.blank? && pass_code.present?

    if raw_number.blank?
      errors.add(:number, :blank)
      return
    end

    normalized = TelephoneNormalization.normalize_to_e164(raw_number)
    unless normalized
      errors.add(:number, :invalid_e164_format)
      return
    end

    if normalized.start_with?("+0")
      errors.add(:number, :country_code_cannot_start_with_zero)
      return
    end

    return if normalized.match?(TelephoneNormalization::E164_FORMAT)

    errors.add(:number, :invalid_e164_format)
    nil

  end
end

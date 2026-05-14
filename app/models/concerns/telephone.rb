# typed: false
# frozen_string_literal: true

module Telephone
  extend ActiveSupport::Concern
  include TelephoneNormalization

  MAX_OTP_ATTEMPTS = 5
  OTP_ATTEMPT_WINDOW = 15.minutes
  OTP_LOCKOUT_DURATION = 15.minutes

  attr_accessor :confirm_policy, :confirm_using_mfa, :pass_code
  attr_writer :raw_number

  included do
    before_validation :normalize_number_from_raw
    before_validation :set_number_digests
    scope :with_number, ->(value) do
      digest = IdentifierBlindIndex.bidx_for_telephone(value)
      digest.present? ? where(number_digest: digest) : none
    end

    after_initialize do
      self.otp_counter = "0" if otp_counter.blank?
      self.otp_private_key = ROTP::Base32.random_base32 if otp_private_key.blank?
      self.otp_attempts_count ||= 0
    end

    encrypts :number

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

  class_methods do
    def find_by_number(value)
      digest = IdentifierBlindIndex.bidx_for_telephone(value)
      return nil if digest.blank?

      find_by(number_digest: digest)
    end
  end

  # OTP-related methods for telephone authentication
  # Stores OTP secret on this telephone record
  def store_otp(otp_private_key, otp_counter, expires_at)
    attrs = {
      otp_private_key: otp_private_key,
      otp_counter: otp_counter,
      otp_expires_at: Time.zone.at(expires_at),
    }

    unless locked?
      attrs[:otp_attempts_count] = 0
      attrs[:locked_at] = "-infinity"
    end

    update!(attrs)
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

  def reregistration_window_active?
    timestamp = respond_to?(:otp_last_sent_at) ? otp_last_sent_at : created_at
    return false if timestamp.blank?
    return false if timestamp == -Float::INFINITY

    timestamp > Common::OtpPolicy::REREGISTRATION_OVERWRITE_WINDOW.ago
  end

  def locked?
    lockout_active? || attempts_locked_without_expiry?
  end

  def lockout_active?
    lockout_expires_at.present? && lockout_expires_at > Time.current
  end

  def lockout_expires_at
    return nil if locked_at.blank? || locked_at == -Float::INFINITY || locked_at == Float::INFINITY

    locked_at
  end

  def increment_attempts!
    operation =
      lambda do
        with_lock do
          next if lockout_active?

          unless attempt_window_active?
            self.otp_last_sent_at = Time.current if respond_to?(:otp_last_sent_at=)
            self.otp_attempts_count = 0
          end

          self.otp_attempts_count = otp_attempts_count.to_i + 1
          self.locked_at = OTP_LOCKOUT_DURATION.from_now if otp_attempts_count >= MAX_OTP_ATTEMPTS
          save!(validate: false)
        end
        reload
      end

    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  def raw_number
    @raw_number.presence || number
  end

  private

  def attempt_window_active?
    timestamp = respond_to?(:otp_last_sent_at) ? otp_last_sent_at : created_at
    return false if timestamp.blank? || timestamp == -Float::INFINITY

    timestamp > OTP_ATTEMPT_WINDOW.ago
  end

  def attempts_locked_without_expiry?
    lockout_expires_at.blank? && attempt_window_active? && otp_attempts_count.to_i >= MAX_OTP_ATTEMPTS
  end

  def normalize_number_from_raw
    value = raw_number
    return if value.blank?

    normalized = TelephoneNormalization.normalize_to_e164(value)
    self.number = normalized if normalized.present?
  end

  def set_number_digests
    digest = IdentifierBlindIndex.bidx_for_telephone(raw_number)
    self.number_bidx = digest if respond_to?(:number_bidx=)
    self.number_digest = digest if respond_to?(:number_digest=)
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

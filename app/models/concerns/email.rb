# typed: false
# frozen_string_literal: true

module Email
  extend ActiveSupport::Concern

  # Requires:
  # - address
  # - address_digest
  # - otp_counter
  # - otp_private_key
  # - otp_attempts_count
  #
  # Optional:
  # - address_bidx
  #
  # Registers:
  # - before_validation :normalize_address_from_raw
  # - before_validation :set_address_digests
  # - scope :with_address
  # - after_initialize OTP defaults
  # - encrypts :address
  # - validate :validate_email_address
  # - validates :confirm_policy
  # - validates :pass_code
  MAX_OTP_ATTEMPTS = 5
  OTP_ATTEMPT_WINDOW = 15.minutes
  OTP_LOCKOUT_DURATION = 15.minutes
  OTP_COOLDOWN_PERIOD = CommonOtpPolicy::SEND_COOLDOWN

  attr_accessor :confirm_policy, :pass_code
  attr_writer :raw_address

  included do
    before_validation :normalize_address_from_raw
    before_validation :set_address_digests
    scope :with_address, ->(value) do
      digest = IdentifierBlindIndex.bidx_for_email(value)
      digest.present? ? where(address_digest: digest) : none
    end

    after_initialize do
      self.otp_counter = "0" if otp_counter.blank?
      self.otp_private_key = ROTP::Base32.random_base32 if otp_private_key.blank?
      self.otp_attempts_count ||= 0
    end

    encrypts :address, downcase: true

    validate :validate_email_address
    validates :confirm_policy, acceptance: true, on: :create,
                               unless: Proc.new { |a| a.raw_address.blank? && a.pass_code.present? }
    validates :pass_code, numericality: { only_integer: true },
                          length: { is: 6 },
                          presence: true,
                          unless: Proc.new { |a| a.pass_code.blank? && a.raw_address.present? }
  end

  class_methods do
    def find_by_address(value)
      digest = IdentifierBlindIndex.bidx_for_email(value)
      return nil if digest.blank?

      find_by(address_digest: digest)
    end
  end

  # OTP-related methods for email authentication
  # Stores OTP secret_credential on this email record
  def store_otp(otp_private_key, otp_counter, expires_at)
    attrs = {
      otp_private_key: otp_private_key,
      otp_counter: otp_counter,
      otp_expires_at: Time.zone.at(expires_at),
      otp_last_sent_at: Time.current,
    }

    unless locked?
      attrs[:otp_attempts_count] = 0
      attrs[:locked_at] = "infinity"
    end

    update!(attrs)
  end

  # Retrieves OTP secret_credential from this email record
  def get_otp
    return nil if otp_private_key.blank? || otp_expired? || locked?

    {
      otp_private_key: otp_private_key,
      otp_counter: Integer(otp_counter.to_s, 10),
      otp_expires_at: otp_expires_at.to_i,
    }
  end

  # Clears OTP secret_credential after verification
  def clear_otp
    update!(
      otp_counter: "0",
      otp_expires_at: "-infinity",
      otp_attempts_count: 0,
      locked_at: "infinity", # Sentinel for unlocked: "locks at infinity" = never locked
      otp_last_sent_at: "-infinity",
    )
  end

  # Checks if OTP has expired
  def otp_expired?
    return true if otp_expires_at.is_a?(Float) && otp_expires_at == -Float::INFINITY

    otp_expires_at.nil? || otp_expires_at <= Time.current
  end

  # Checks if OTP is still active
  def otp_active?
    !otp_expired? && !locked?
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

  def otp_cooldown_active?
    return false if otp_last_sent_at.blank?
    return false if otp_last_sent_at == -Float::INFINITY

    otp_last_sent_at > OTP_COOLDOWN_PERIOD.ago
  end

  def otp_cooldown_remaining
    return 0 unless otp_cooldown_active?

    (otp_last_sent_at + OTP_COOLDOWN_PERIOD) - Time.current
  end

  def reregistration_window_active?
    return false if otp_last_sent_at.blank?
    return false if otp_last_sent_at == -Float::INFINITY

    otp_last_sent_at > CommonOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW.ago
  end

  def increment_attempts!
    operation =
      lambda do
        with_lock do
          next if lockout_active?

          unless attempt_window_active?
            self.otp_last_sent_at = Time.current
            self.otp_attempts_count = 0
          end

          self.otp_attempts_count = otp_attempts_count.to_i + 1
          self.locked_at = OTP_LOCKOUT_DURATION.from_now if otp_attempts_count >= MAX_OTP_ATTEMPTS
          save!
        end
        reload
      end

    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  def raw_address
    @raw_address.presence || address
  end

  private

  def attempt_window_active?
    return false if otp_last_sent_at.blank? || otp_last_sent_at == -Float::INFINITY

    otp_last_sent_at > OTP_ATTEMPT_WINDOW.ago
  end

  def attempts_locked_without_expiry?
    lockout_expires_at.blank? && attempt_window_active? && otp_attempts_count.to_i >= MAX_OTP_ATTEMPTS
  end

  def normalize_address_from_raw
    value = raw_address
    return if value.blank?

    normalized = JitUtilsEmailValidator.normalize(value)
    self.address = normalized if normalized.present?
  end

  def set_address_digests
    digest = IdentifierBlindIndex.bidx_for_email(raw_address)
    self.address_bidx = digest if respond_to?(:address_bidx=)
    self.address_digest = digest if respond_to?(:address_digest=)
  end

  def validate_email_address
    return if raw_address.blank? && pass_code.present?

    if raw_address.blank?
      errors.add(:address, :blank)
      return
    end

    normalized = JitUtilsEmailValidator.normalize(raw_address)
    return if normalized

    errors.add(:address, :invalid)
    nil

  end
end

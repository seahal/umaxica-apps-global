# typed: false
# frozen_string_literal: true

module Email
  extend ActiveSupport::Concern

  MAX_OTP_ATTEMPTS = 3
  OTP_COOLDOWN_PERIOD = Common::OtpPolicy::SEND_COOLDOWN

  attr_accessor :confirm_policy, :pass_code
  attr_writer :raw_address

  included do
    before_validation :normalize_address_from_raw
    before_validation :set_address_digests
    scope :with_address, ->(value) do
      digest = IdentifierBlindIndex.bidx_for_email(value)
      digest.present? ? where(address_bidx: digest) : none
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
      with_address(value).first
    end
  end

  # OTP-related methods for email authentication
  # Stores OTP secret on this email record
  def store_otp(otp_private_key, otp_counter, expires_at)
    update!(
      otp_private_key: otp_private_key,
      otp_counter: otp_counter,
      otp_expires_at: Time.zone.at(expires_at),
      otp_attempts_count: 0,
      locked_at: "infinity", # Sentinel for unlocked: "locks at infinity" = never locked
      otp_last_sent_at: Time.current,
    )
  end

  # Retrieves OTP secret from this email record
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
    # locked_at == Float::INFINITY  -> new sentinel for "unlocked" (set by store_otp/clear_otp)
    # locked_at == -Float::INFINITY -> old sentinel for "unlocked" (backward-compatible with existing rows)
    # Any real timestamp in the past means the account is locked by time.
    is_locked_by_time = locked_at.present? &&
      locked_at != -Float::INFINITY &&
      locked_at != Float::INFINITY
    is_locked_by_attempts = otp_attempts_count >= MAX_OTP_ATTEMPTS
    is_locked_by_time || is_locked_by_attempts
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

  def increment_attempts!
    # rubocop:disable Rails/SkipsModelValidations
    increment!(:otp_attempts_count)
    # Conditionally set locked_at when threshold is reached and not already locked
    self.class
      .where(id: id)
      .where(otp_attempts_count: MAX_OTP_ATTEMPTS..)
      .where("locked_at IS NULL OR locked_at = '-infinity'::timestamp OR locked_at = 'infinity'::timestamp")
      .update_all(locked_at: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
    reload
  end

  def raw_address
    @raw_address.presence || address
  end

  private

  def normalize_address_from_raw
    value = raw_address
    return if value.blank?

    normalized = Jit::Utils::EmailValidator.normalize(value)
    self.address = normalized if normalized.present?
  end

  def set_address_digests
    digest = IdentifierBlindIndex.bidx_for_email(raw_address)
    self.address_bidx = digest
    self.address_digest = digest if respond_to?(:address_digest=)
  end

  def validate_email_address
    return if raw_address.blank? && pass_code.present?

    if raw_address.blank?
      errors.add(:address, :blank)
      return
    end

    normalized = Jit::Utils::EmailValidator.normalize(raw_address)
    return if normalized

    errors.add(:address, :invalid)
    nil

  end
end

# typed: false
# frozen_string_literal: true

module EmailValidation
  extend ActiveSupport::Concern

  private

  def validate_and_normalize_email(email)
    Jit::Utils::EmailValidator.normalize(email)
  end

  def valid_email_format?(email)
    Jit::Utils::EmailValidator.valid?(email)
  end

  def identity_email_model
    UserEmail
  end

  def find_email_with_timing_protection(email)
    target_seconds = email_lookup_timing_protection_seconds
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    digest = IdentifierBlindIndex.bidx_for_email(email)
    result = digest ? identity_email_model.find_by(address_digest: digest) : nil

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    remaining = target_seconds - elapsed
    sleep(remaining) if remaining.positive?

    result
  end

  def email_lookup_timing_protection_seconds
    return 0.0 if Rails.env.test? && ENV["ENABLE_TIMING_PROTECTION_IN_TEST"] != "1"

    0.05
  end
end

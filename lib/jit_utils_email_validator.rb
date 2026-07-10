# typed: false
# frozen_string_literal: true

require "uri"

module JitUtilsEmailValidator
  module_function

  # Validates and normalizes email address
  # Returns normalized email or nil if invalid
  # @param email [String, nil]
  # @return [String, nil]
  def normalize(email)
    return nil if email.blank?

    normalized = email.strip.downcase
    return nil unless valid?(normalized)

    normalized
  end

  # Validates email format using URI::MailTo::EMAIL_REGEXP
  # @param email [String]
  # @return [Boolean]
  def valid?(email)
    return false if email.blank?

    email.match?(URI::MailTo::EMAIL_REGEXP)
  end
end

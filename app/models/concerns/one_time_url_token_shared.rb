# typed: false
# frozen_string_literal: true

# Shared opaque one-time URL token primitives.
# Keep this separate from refresh-token concerns so logout handoff tokens do not
# inherit refresh-family or rotation semantics.
module OneTimeUrlTokenShared
  extend ActiveSupport::Concern

  require "sha3"

  TOKEN_SEPARATOR = "."
  VERIFIER_BYTES = 48

  class_methods do
    def token_separator
      TOKEN_SEPARATOR
    end

    def verifier_bytes
      VERIFIER_BYTES
    end

    def generate_one_time_url_token(public_id:, verifier: nil)
      verifier ||= SecureRandom.urlsafe_base64(verifier_bytes)
      ["#{public_id}#{token_separator}#{verifier}", verifier]
    end

    def parse_one_time_url_token(raw_token)
      return nil if raw_token.blank?

      public_id, verifier = raw_token.split(token_separator, 2)
      return nil if public_id.blank? || verifier.blank?

      [public_id, verifier]
    end

    def digest_one_time_url_verifier(verifier)
      SHA3::Digest::SHA3_384.digest(verifier.to_s)
    end

    def secure_compare?(expected, actual)
      return false if expected.blank? || actual.blank?

      ActiveSupport::SecurityUtils.secure_compare(expected, actual)
    end
  end

  delegate :parse_one_time_url_token, :digest_one_time_url_verifier,
           :secure_compare?, :token_separator, :verifier_bytes,
           to: :class
end

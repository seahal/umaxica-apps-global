# typed: false
# frozen_string_literal: true

require "base64"
require "securerandom"

module JitSecurityJwtJtiGenerator
  DEFAULT_BYTES = 20
  MINIMUM_BYTES = 16

  BYTE_LENGTH_MAPPING = {
    16 => 22,
    20 => 27,
  }.freeze

  BASE64URL_REGEX = /\A[A-Za-z0-9_-]+\z/.freeze

  # Base64URL encoding without padding: 16 bytes -> 22 chars, 20 bytes -> 27 chars.
  def self.generate(nbytes = DEFAULT_BYTES)
    raw = SecureRandom.random_bytes(nbytes)
    Base64.urlsafe_encode64(raw, padding: false)
  end

  def self.encoded_length(nbytes)
    return BYTE_LENGTH_MAPPING[nbytes] if BYTE_LENGTH_MAPPING.key?(nbytes)

    base = (nbytes / 3) * 4
    remainder = nbytes % 3
    base + case remainder
    when 1
      2
    when 2
      3
    else
      0
    end
  end
end

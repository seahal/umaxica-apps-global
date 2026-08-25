# typed: false
# frozen_string_literal: true

require "openssl"

module AuthenticationRateLimitKey
  PURPOSE = "authentication.rate_limit.identifier"

  module_function

  def for(surface:, identifier:)
    surface_key = surface.to_s
    normalized = identifier.to_s.strip.downcase
    return "#{surface_key}:unbound" if normalized.blank?

    digest = OpenSSL::HMAC.hexdigest("SHA256", secret_key, "#{surface_key}:#{normalized}")
    "#{surface_key}:identifier:#{digest}"
  end

  def secret_key
    Rails.application.key_generator.generate_key(PURPOSE, 32)
  end
end

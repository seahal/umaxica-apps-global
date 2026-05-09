# typed: false
# frozen_string_literal: true

# Helper methods for working with cookies in integration tests
module CookieHelper
  def preference_refresh_cookie_name
    Rails.env.production? ? "__Secure-preference_refresh" : "preference_refresh"
  end

  def preference_access_cookie_name
    Rails.env.production? ? "__Secure-preference_access" : "preference_access"
  end

  def preference_device_id_cookie_name
    preference_refresh_cookie_name.sub("preference_refresh", "preference_device_id")
  end

  # Read a signed cookie value by key
  # @param key [Symbol, String] The cookie key to read
  # @return [String, nil] The signed cookie value or nil if not found
  def signed_cookie(key)
    # Create a proper cookie jar using the request object
    cookie_jar = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
    cookie_jar.signed[key]
  end

  # Set an encrypted cookie value for integration tests.
  # Rack::Test::CookieJar does not support .encrypted, so we build a
  # real ActionDispatch cookie jar, encrypt through it, then copy the
  # raw (already-encrypted) value into the test cookie jar.
  def set_encrypted_cookie(key, value, cookie_jar: cookies)
    jar = ActionDispatch::Cookies::CookieJar.build(
      ActionDispatch::Request.new(Rails.application.env_config), {},
    )
    jar.encrypted[key] = value
    cookie_jar[key] = jar[key]
  end

  # Read an encrypted cookie value from the integration test cookie jar.
  def read_encrypted_cookie(key, cookie_jar: cookies)
    jar = ActionDispatch::Cookies::CookieJar.build(
      ActionDispatch::Request.new(Rails.application.env_config), { key => cookie_jar[key] },
    )
    jar.encrypted[key]
  end

  def preference_cookie_payload(key, host: request&.host)
    token = cookies[key]
    return nil if token.blank?

    Preference::Token.decode(token, host: host.to_s.presence || "unknown")
  end

  def response_cookie_expiry(name)
    raw_header = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines =
      case raw_header
      when Array
        raw_header
      when String
        raw_header.split("\n")
      else
        []
      end

    cookie_line = lines.find { |line| line.start_with?("#{name}=") }
    return nil unless cookie_line

    match = cookie_line.match(/expires=([^;]+)/i)
    return nil unless match

    Time.httpdate(match[1])
  rescue ArgumentError, TypeError
    nil
  end
end

# Include the helper in ActionDispatch::IntegrationTest
ActiveSupport.on_load(:action_dispatch_integration_test) { include CookieHelper }

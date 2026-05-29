# typed: false
# frozen_string_literal: true

module SessionCookieConfig
  module_function

  # Determines whether to force secure cookie settings.
  # Returns true outside development/test, or when FORCE_SECURE_COOKIES=1.
  def force_secure?(id_service_host:, rails_env: Rails.env)
    return false if rails_env.test?

    return true if rails_env.production?
    return true if ENV["FORCE_SECURE_COOKIES"] == "1"
    return true unless rails_env.development?

    false
  end

  # Returns the session cookie key based on secure mode.
  # Production uses __Host- prefix for strict cookie binding.
  def cookie_key(force_secure:)
    force_secure ? "__Host-session" : "session"
  end

  def partitioned?(rails_env: Rails.env)
    rails_env.production?
  end
end

# typed: false
# frozen_string_literal: true

module SessionCookieConfig
  module_function

  # Determines whether to force secure cookie settings.
  # Returns true in production, or when FORCE_SECURE_COOKIES=1,
  # but never in test or development environments.
  def force_secure?(id_service_host:, rails_env: Rails.env)
    non_local_host =
      id_service_host.present? &&
      id_service_host.exclude?("localhost") &&
      !id_service_host.start_with?("127.") &&
      !id_service_host.start_with?("0.") # non-routable bind address

    (rails_env.production? ||
      ENV["FORCE_SECURE_COOKIES"] == "1" ||
      (non_local_host && !rails_env.development?)) &&
      !rails_env.test?
  end

  # Returns the session cookie key based on secure mode.
  # Production uses __Host- prefix for strict cookie binding.
  def cookie_key(force_secure:)
    force_secure ? "__Host-session" : "session"
  end
end

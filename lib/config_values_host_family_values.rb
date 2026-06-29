# frozen_string_literal: true

module ConfigValues
  HostFamilyValues =
    Data.define(
      :acme_service,
      :acme_corporate,
      :acme_staff,
      :sign_service,
      :sign_corporate,
      :sign_staff,
      :core_service,
      :core_corporate,
      :core_staff,
      :base_service,
      :base_corporate,
      :base_staff,
      :palm_service,
      :palm_corporate,
      :palm_staff,
      :help_service,
      :help_corporate,
      :help_staff,
      :info_service,
      :info_corporate,
      :info_staff,
    ) do
      def acme_origins
        [acme_service, acme_corporate, acme_staff]
      end

      def sign_origins
        [sign_service, sign_corporate, sign_staff]
      end

      def core_origins
        [core_service, core_corporate, core_staff]
      end

      def auth_service = sign_service

      def auth_corporate = sign_corporate

      def auth_staff = sign_staff

      def auth_origins
        [auth_service, auth_corporate, auth_staff]
      end

      def side_service = base_service

      def side_corporate = base_corporate

      def side_staff = base_staff

      def side_origins
        [side_service, side_corporate, side_staff]
      end

      def base_origins
        [base_service, base_corporate, base_staff]
      end

      def palm_origins
        [palm_service, palm_corporate, palm_staff]
      end

      def info_origins
        [info_service, info_corporate, info_staff]
      end
    end
end

ConfigValuesHostFamilyValues = ConfigValues::HostFamilyValues

class << ConfigValues::HostFamilyValues
  def build(env:, production:)
    ConfigValues::HostFamilyValues.new(
      acme_service: origin(env, "ACME_SERVICE_URL", production ? nil : "acme.app.localhost", production: production),
      acme_corporate: origin(
        env, "ACME_CORPORATE_URL", production ? nil : "acme.com.localhost",
        production: production,
      ),
      acme_staff: origin(env, "ACME_STAFF_URL", production ? nil : "acme.org.localhost", production: production),
      sign_service: origin(env, "AUTH_SERVICE_URL", production ? nil : "sign.app.localhost", production: production),
      sign_corporate: origin(
        env, "AUTH_CORPORATE_URL", production ? nil : "sign.com.localhost",
        production: production,
      ),
      sign_staff: origin(env, "AUTH_STAFF_URL", production ? nil : "sign.org.localhost", production: production),
      core_service: origin(env, "CORE_SERVICE_URL", production ? nil : "jpx.umaxica.app", production: production),
      core_corporate: origin(
        env,
        "CORE_CORPORATE_URL",
        production ? nil : "jpx.umaxica.com",
        production: production,
      ),
      core_staff: origin(env, "CORE_STAFF_URL", production ? nil : "jpx.umaxica.org", production: production),
      base_service: origin(
        env,
        base_key(env, "SERVICE"),
        production ? nil : "www-jp.umaxica.app",
        production: production,
      ),
      base_corporate: origin(
        env,
        base_key(env, "CORPORATE"),
        production ? nil : "www-jp.umaxica.com",
        production: production,
      ),
      base_staff: origin(
        env,
        base_key(env, "STAFF"),
        production ? nil : "www-jp.umaxica.org",
        production: production,
      ),
      palm_service: origin(env, "PALM_SERVICE_URL", production ? nil : "palm-jp.umaxica.app", production: production),
      palm_corporate: origin(
        env,
        "PALM_CORPORATE_URL",
        production ? nil : "palm-jp.umaxica.com",
        production: production,
      ),
      palm_staff: origin(env, "PALM_STAFF_URL", production ? nil : "palm-jp.umaxica.org", production: production),
      help_service: origin(env, "HELP_SERVICE_URL", production ? nil : "help.app.localhost", production: production),
      help_corporate: origin(
        env,
        "HELP_CORPORATE_URL",
        production ? nil : "help.com.localhost",
        production: production,
      ),
      help_staff: origin(env, "HELP_STAFF_URL", production ? nil : "help.org.localhost", production: production),
      info_service: origin(env, "INFO_SERVICE_URL", production ? nil : "info.app.localhost", production: production),
      info_corporate: origin(
        env,
        "INFO_CORPORATE_URL",
        production ? nil : "info.com.localhost",
        production: production,
      ),
      info_staff: origin(env, "INFO_STAFF_URL", production ? nil : "info.org.localhost", production: production),
    ).freeze
  end

  # Resolves the ENV key for a base surface (service/corporate/staff).
  # Prefers SIDE_* over BASE_* over PUBLIC_BASE_* so that explicit private-routing
  # overrides take precedence, but PUBLIC_BASE_* (browser-visible hosts from docker
  # env) are picked up when neither private key is set.
  def base_key(env, surface)
    if env.key?("SIDE_#{surface}_URL")
      "SIDE_#{surface}_URL"
    elsif env.key?("BASE_#{surface}_URL")
      "BASE_#{surface}_URL"
    else
      "PUBLIC_BASE_#{surface}_URL"
    end
  end

  def origin(env, key, fallback, production:)
    raw = production ? env.fetch(key) : env.fetch(key, fallback)
    allow_localhost = !production
    uri = raw.to_s.match?(%r{\Ahttps?://}) ? raw : "https://#{raw}"
    ConfigValues.build(uri, allow_localhost: allow_localhost)
  rescue KeyError
    raise KeyError, "Missing required ENV key: #{key}"
  end
end

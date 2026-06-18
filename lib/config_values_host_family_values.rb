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

      def base_origins
        [base_service, base_corporate, base_staff]
      end

      def palm_origins
        [palm_service, palm_corporate, palm_staff]
      end
    end
end

ConfigValuesHostFamilyValues = ConfigValues::HostFamilyValues

class << ConfigValues::HostFamilyValues
  def build(env:, production:)
    ConfigValues::HostFamilyValues.new(
      acme_service: origin(env, "ACME_SERVICE_URL", production ? nil : "www.app.localhost", production: production),
      acme_corporate: origin(env, "ACME_CORPORATE_URL", production ? nil : "www.com.localhost", production: production),
      acme_staff: origin(env, "ACME_STAFF_URL", production ? nil : "www.org.localhost", production: production),
      sign_service: origin(env, "SIGN_SERVICE_URL", production ? nil : "id.app.localhost", production: production),
      sign_corporate: origin(env, "SIGN_CORPORATE_URL", production ? nil : "id.com.localhost", production: production),
      sign_staff: origin(env, "SIGN_STAFF_URL", production ? nil : "id.org.localhost", production: production),
      core_service: origin(env, "CORE_SERVICE_URL", production ? nil : "www-jp.umaxica.app", production: production),
      core_corporate: origin(
        env,
        "CORE_CORPORATE_URL",
        production ? nil : "www-jp.umaxica.com",
        production: production,
      ),
      core_staff: origin(env, "CORE_STAFF_URL", production ? nil : "www-jp.umaxica.org", production: production),
      base_service: origin(env, "BASE_SERVICE_URL", production ? nil : "base-jp.umaxica.app", production: production),
      base_corporate: origin(
        env,
        "BASE_CORPORATE_URL",
        production ? nil : "base-jp.umaxica.com",
        production: production,
      ),
      base_staff: origin(env, "BASE_STAFF_URL", production ? nil : "base-jp.umaxica.org", production: production),
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
    ).freeze
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

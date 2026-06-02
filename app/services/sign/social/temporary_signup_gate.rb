# typed: false
# frozen_string_literal: true

require "set"

module Sign
  module Social
    module TemporarySignupGate
      SIGNUP_ENABLED_ENV = "ORG_GOOGLE_SIGNUP_ENABLED"
      SIGNUP_ALLOWLIST_ENV = "ORG_GOOGLE_SIGNUP_ALLOWLIST"
      PRODUCTION_SIGNUP_ERROR =
        "ORG_GOOGLE_SIGNUP_ENABLED must not be true in production " \
        "while org Google signup remains a temporary gateway"

      module_function

      def signup_enabled?(environment: Rails.env, env: ENV)
        return false if production?(environment)

        env_true?(env, SIGNUP_ENABLED_ENV)
      end

      # TEMP(org-google-social-gateway): remove before production cleanup
      def provisioning_allowed?(email, env: ENV)
        normalized_email = normalize_email(email)
        return false if normalized_email.blank?

        signup_allowlist(env).include?(normalized_email)
      end

      def validate_production_configuration!(environment: Rails.env, env: ENV)
        return unless production?(environment)
        return unless env_true?(env, SIGNUP_ENABLED_ENV)

        raise PRODUCTION_SIGNUP_ERROR
      end

      def signup_allowlist(env = ENV)
        env.fetch(SIGNUP_ALLOWLIST_ENV, "").split(",").filter_map do |value|
          normalize_email(value)
        end.to_set
      end

      def env_true?(env, key)
        env[key].to_s.casecmp("true").zero?
      end

      def normalize_email(value)
        value.to_s.strip.downcase.presence
      end

      def production?(environment)
        environment.to_s == "production"
      end

      private_class_method :env_true?, :normalize_email, :production?
    end
  end
end

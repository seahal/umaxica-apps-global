# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  # First availability adapter, reading strict true/false settings from the
  # environment.
  #
  class EnvironmentProviderAvailabilityAdapter
    include ProviderAvailabilityPort

    ConfigurationError = Class.new(StandardError)

    PROVIDER_ENV_NAMES = {
      "apple" => "APPLE_SOCIAL_CEREMONY_ENABLED",
      "google" => "GOOGLE_SOCIAL_CEREMONY_ENABLED",
      "entra" => "ENTRA_SOCIAL_CEREMONY_ENABLED",
    }.freeze
    START_OPERATIONS = %w(link login signup).freeze

    def initialize(environment: ENV, clock: -> { Time.current })
      @clock = clock
      @environment = environment
    end

    def start_decision(provider:, operation:, context:)
      validate_context(context)
      raise ArgumentError, "operation is unsupported" unless START_OPERATIONS.include?(operation)

      enabled = enabled_for(provider)
      build_decision(
        state: enabled ? :enabled : :disabled,
        reason_code: enabled ? "configured_enabled" : "configured_disabled",
      )
    end

    def callback_decision(provider:, ceremony:, context:)
      validate_context(context)
      raise ArgumentError, "ceremony is required" if ceremony.nil?

      enabled = enabled_for(provider)
      build_decision(
        state: enabled ? :enabled : :draining,
        reason_code: enabled ? "configured_enabled" : "issued_before_disable",
      )
    end

    private

    def enabled_for(provider)
      env_name = PROVIDER_ENV_NAMES.fetch(provider)
      parse_enabled(@environment.fetch(env_name), env_name)
    rescue KeyError => e
      raise e if PROVIDER_ENV_NAMES.key?(provider)

      raise ArgumentError, "provider is unsupported"
    end

    def validate_context(context)
      raise ArgumentError, "context is required" if context.nil?
    end

    def parse_enabled(value, env_name)
      case value
      when "true" then true
      when "false" then false
      else
        raise ConfigurationError, "#{env_name} must be true or false"
      end
    end

    def build_decision(state:, reason_code:)
      AvailabilityDecision.new(
        state: state,
        source: "environment",
        configuration_version: nil,
        reason_code: reason_code,
        incident_id: nil,
        observed_at: @clock.call,
      )
    end
  end
end

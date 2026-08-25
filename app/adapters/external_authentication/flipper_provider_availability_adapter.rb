# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  # Availability adapter backed by Flipper feature flags, replacing the
  # deploy-time *_SOCIAL_CEREMONY_ENABLED environment switches with a runtime
  # kill switch that does not require a restart.
  #
  # An unknown or unset feature reads as disabled. This is deliberate: the flag
  # is a kill switch for an external authentication ceremony, so losing the
  # backing store must stop new ceremonies rather than let them through.
  class FlipperProviderAvailabilityAdapter
    include ProviderAvailabilityPort

    # The surface segment is part of the key because a provider is mounted on exactly one
    # trust boundary (see OmniAuthSocialProviderHostMatrix): flipping a switch in the Flipper
    # UI must make the affected surface obvious without cross-referencing this file.
    PROVIDER_FEATURE_NAMES = {
      "apple" => :social_ceremony_app_apple,
      "google" => :social_ceremony_app_google,
      "entra" => :social_ceremony_org_entra,
    }.freeze
    START_OPERATIONS = %w(link login signup).freeze

    def initialize(flipper: Flipper, clock: -> { Time.current })
      @clock = clock
      @flipper = flipper
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
      feature_name = PROVIDER_FEATURE_NAMES[provider]
      raise ArgumentError, "provider is unsupported" if feature_name.nil?

      FeatureFlags.enabled?(feature_name, flipper: @flipper)
    end

    def validate_context(context)
      raise ArgumentError, "context is required" if context.nil?
    end

    def build_decision(state:, reason_code:)
      AvailabilityDecision.new(
        state: state,
        source: "flipper",
        configuration_version: nil,
        reason_code: reason_code,
        incident_id: nil,
        observed_at: @clock.call,
      )
    end
  end
end

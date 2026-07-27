# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class AvailabilityDecision < Data.define(
    :state,
    :source,
    :configuration_version,
    :reason_code,
    :incident_id,
    :observed_at,
  )
    STATES = %i(enabled disabled draining incident_stop).freeze

    def initialize(state:, source:, configuration_version:, reason_code:, incident_id:, observed_at:)
      raise ArgumentError, "state is unsupported" unless STATES.include?(state)
      raise ArgumentError, "source is required" unless source.is_a?(String) && source.present?
      unless observed_at.is_a?(Time) || observed_at.is_a?(ActiveSupport::TimeWithZone)
        raise ArgumentError, "observed_at must be a time"
      end

      super(
        state: state,
        source: source.dup.freeze,
        configuration_version: immutable_optional_string(configuration_version, :configuration_version),
        reason_code: immutable_optional_string(reason_code, :reason_code),
        incident_id: immutable_optional_string(incident_id, :incident_id),
        observed_at: observed_at.dup.freeze,
      )
    end

    private

    def immutable_optional_string(value, name)
      return nil if value.nil?
      raise ArgumentError, "#{name} must be a string" unless value.is_a?(String)

      value.dup.freeze
    end
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationAvailabilityDecisionTest < ActiveSupport::TestCase
  test "represents normalized provider availability metadata" do
    observed_at = Time.zone.local(2026, 7, 24, 12, 0, 0)

    decision = ExternalAuthentication::AvailabilityDecision.new(
      state: :disabled,
      source: "environment",
      configuration_version: nil,
      reason_code: "configured_disabled",
      incident_id: nil,
      observed_at: observed_at,
    )

    assert_equal :disabled, decision.state
    assert_equal "environment", decision.source
    assert_equal "configured_disabled", decision.reason_code
    assert_nil decision.configuration_version
    assert_nil decision.incident_id
    assert_equal observed_at, decision.observed_at
    assert_predicate decision, :frozen?
  end

  test "supports the complete typed state contract" do
    %i(enabled disabled draining incident_stop).each do |state|
      decision = ExternalAuthentication::AvailabilityDecision.new(
        state: state,
        source: "contract",
        configuration_version: nil,
        reason_code: nil,
        incident_id: nil,
        observed_at: Time.zone.local(2026, 7, 24, 12, 0, 0),
      )

      assert_equal state, decision.state
    end
  end

  test "rejects unknown availability states" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::AvailabilityDecision.new(
          state: :unknown,
          source: "contract",
          configuration_version: nil,
          reason_code: nil,
          incident_id: nil,
          observed_at: Time.zone.local(2026, 7, 24, 12, 0, 0),
        )
      end

    assert_equal "state is unsupported", error.message
  end
end

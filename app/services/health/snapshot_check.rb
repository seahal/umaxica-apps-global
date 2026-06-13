# typed: false
# frozen_string_literal: true

module Health
  # Aggregates liveness, readiness, and startup into one snapshot for the
  # human-facing /health endpoint. Not used by Kubernetes probes.
  class SnapshotCheck
    def self.call(profile:)
      new(profile: profile).call
    end

    def initialize(profile:)
      @profile = profile
    end

    def call
      sub_results = {
        liveness: Health::LivenessCheck.call(profile: profile),
        readiness: Health::ReadinessCheck.call(profile: profile),
        startup: Health::StartupCheck.call(profile: profile),
      }

      status = sub_results.values.all?(&:ok?) ? :ok : :unready

      Health::CheckResult.new(
        check: :health,
        status: status,
        surface: profile.surface_label,
        dependencies: sub_results.transform_keys(&:to_s).transform_values(&:as_public_json),
      )
    end

    private

    attr_reader :profile
  end
end

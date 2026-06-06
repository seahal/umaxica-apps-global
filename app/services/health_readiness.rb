# typed: false
# frozen_string_literal: true

class HealthReadiness
  CACHE_TTL = 2.seconds
  TOTAL_DEADLINE = 1.0

  def self.call(profile:)
    new(profile: profile).call
  end

  def initialize(profile:, cache: Rails.cache)
    @profile = profile
    @cache = cache
  end

  def call
    cache.fetch(cache_key, expires_in: CACHE_TTL) do
      build_report
    end
  end

  private

  attr_reader :profile, :cache

  def build_report
    checks =
      Timeout.timeout(TOTAL_DEADLINE, Health::DeadlineExceeded) do
        profile.readiness_checks.map(&:call)
      end

    HealthReport.aggregate(profile: profile, probe: :ready, checks: checks)
  rescue Health::DeadlineExceeded
    HealthReport.aggregate(
      profile: profile,
      probe: :ready,
      checks: [HealthCheckResult.new(kind: :deadline, status: :unready, message: "Deadline exceeded")],
    )
  end

  def cache_key
    ["health", profile.cache_key, "ready", Rails.app.revision.to_s].join(":")
  end
end

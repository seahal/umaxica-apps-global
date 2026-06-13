# typed: false
# frozen_string_literal: true

module Health
  # Readiness probe: decides whether traffic may be routed to this instance.
  # Runs the profile's dependency checks (currently database connectivity)
  # behind a total deadline, and caches the result briefly to absorb bursts.
  class ReadinessCheck
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
        build_result
      end
    end

    private

    attr_reader :profile, :cache

    def build_result
      results =
        Timeout.timeout(TOTAL_DEADLINE, Health::DeadlineExceeded) do
          profile.readiness_checks.map(&:call)
        end

      aggregate(results)
    rescue Health::DeadlineExceeded
      aggregate([Health::DependencyResult.new(kind: :deadline, status: :unready, message: "Deadline exceeded")])
    end

    def aggregate(results)
      status = profile.status_policy.status_for(results)

      Health::CheckResult.new(
        check: :readiness,
        status: status,
        surface: profile.surface_label,
        dependencies: dependencies_for(results),
      )
    end

    # Collapses one-or-more dependency results per kind into a single public
    # status: "failed" if any check of that kind failed, otherwise "ok".
    def dependencies_for(results)
      results
        .group_by(&:kind)
        .transform_keys(&:to_s)
        .transform_values { |kind_results| kind_results.all?(&:ok?) ? "ok" : "failed" }
    end

    def cache_key
      ["health", profile.cache_key, "readiness", Rails.app.revision.to_s].join(":")
    end
  end
end

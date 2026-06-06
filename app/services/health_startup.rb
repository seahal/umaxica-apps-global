# typed: false
# frozen_string_literal: true

class HealthStartup
  def self.call(profile:)
    checks = [HealthChecksBoot.new.call]

    HealthReport.aggregate(profile: profile, probe: :startup, checks: checks)
  end
end

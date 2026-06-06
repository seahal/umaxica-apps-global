# typed: false
# frozen_string_literal: true

module Health
  class Startup
    def self.call(profile:)
      checks = [Health::Checks::Boot.new.call]

      Health::Report.aggregate(profile: profile, probe: :startup, checks: checks)
    end
  end
end

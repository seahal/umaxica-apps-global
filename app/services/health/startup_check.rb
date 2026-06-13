# typed: false
# frozen_string_literal: true

module Health
  # Startup probe: confirms boot/initialization completed. Lightweight by
  # design - it only consults the boot check and never external dependencies.
  class StartupCheck
    def self.call(profile:)
      new(profile: profile).call
    end

    def initialize(profile:)
      @profile = profile
    end

    def call
      boot = Health::Checks::Boot.new.call
      status = profile.status_policy.status_for([boot])

      Health::CheckResult.new(check: :startup, status: status, surface: profile.surface_label)
    end

    private

    attr_reader :profile
  end
end

# typed: false
# frozen_string_literal: true

module Health
  # Liveness probe: only confirms the Rails process can respond. It must not
  # touch any external dependency (DB, Redis, external APIs, etc.).
  class LivenessCheck
    def self.call(profile:)
      new(profile: profile).call
    end

    def initialize(profile:)
      @profile = profile
    end

    def call
      status = Rails.application.initialized? ? :ok : :starting

      Health::CheckResult.new(check: :liveness, status: status, surface: profile.surface_label)
    end

    private

    attr_reader :profile
  end
end

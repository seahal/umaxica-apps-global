# typed: false
# frozen_string_literal: true

module Health
  MissingProfileError = Class.new(StandardError) unless const_defined?(:MissingProfileError, false)

  module Controller
    extend ActiveSupport::Concern

    def show_health_snapshot
      @health_report = Health::Readiness.call(profile: health_profile)

      render(
        "health/show",
        formats: :html,
        status: Health::StatusPolicy.http_status(@health_report.status, probe: :ready),
      )
    end

    def show_live
      report = Health::Report.live(profile: health_profile)

      render_health_json(report, probe: :live)
    end

    def show_ready
      report = Health::Readiness.call(profile: health_profile)

      render_health_json(report, probe: :ready)
    end

    def show_startup
      report = Health::Startup.call(profile: health_profile)

      render_health_json(report, probe: :startup)
    end

    private

    def health_profile
      unless self.class.const_defined?(:HEALTH_PROFILE, false)
        raise Health::MissingProfileError, "#{self.class.name} must define its own HEALTH_PROFILE"
      end

      self.class.const_get(:HEALTH_PROFILE, false)
    end

    def render_health_json(report, probe:)
      render json: report.as_public_json, status: Health::StatusPolicy.http_status(report.status, probe: probe)
    end
  end
end

# typed: false
# frozen_string_literal: true

module HealthEndpoint
  extend ActiveSupport::Concern

  MissingProfileError = Class.new(StandardError) unless const_defined?(:MissingProfileError, false)

  def show_health_snapshot
    @health_report = HealthReadiness.call(profile: health_profile)

    render(
      "shared/health/show",
      formats: :html,
      status: HealthStatusPolicy.http_status(@health_report.status, probe: :ready),
    )
  end

  def show_live
    report = HealthReport.live(profile: health_profile)

    render_health_json(report, probe: :live)
  end

  def show_ready
    report = HealthReadiness.call(profile: health_profile)

    render_health_json(report, probe: :ready)
  end

  def show_startup
    report = HealthStartup.call(profile: health_profile)

    render_health_json(report, probe: :startup)
  end

  private

  def health_profile
    unless self.class.const_defined?(:HEALTH_PROFILE, false)
      raise HealthEndpoint::MissingProfileError, "#{self.class.name} must define its own HEALTH_PROFILE"
    end

    self.class.const_get(:HEALTH_PROFILE, false)
  end

  def render_health_json(report, probe:)
    render json: report.as_public_json, status: HealthStatusPolicy.http_status(report.status, probe: probe)
  end
end

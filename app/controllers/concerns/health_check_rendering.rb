# typed: false
# frozen_string_literal: true

# Shared rendering for health controllers. Every health endpoint derives its
# response from a Health::CheckResult through this concern, so no controller
# hand-rolls health JSON or duplicates the status mapping.
module HealthCheckRendering
  extend ActiveSupport::Concern

  # Probe endpoints (liveness/readiness/startup): JSON only. No respond_to,
  # no HTML fallback, no layout, no flash, no redirect.
  def render_probe(result)
    render json: result.as_public_json, status: result.http_status
  end

  # Snapshot endpoint (/health): HTML for browsers, JSON when requested.
  def render_snapshot(result)
    @health_snapshot = result

    return head :not_acceptable unless request.format.html?

    render "shared/health/show", formats: :html, status: result.http_status
  end

  private

  def health_profile
    unless self.class.const_defined?(:HEALTH_PROFILE, false)
      raise Health::MissingProfileError, "#{self.class.name} must define its own HEALTH_PROFILE"
    end

    self.class.const_get(:HEALTH_PROFILE, false)
  end
end

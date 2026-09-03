# typed: false
# frozen_string_literal: true

# Shared plain-text rendering for health controllers.
module HealthCheckRendering
  extend ActiveSupport::Concern

  included do
    before_action :disable_health_response_cache
  end

  def render_probe(result)
    render plain: result.ok? ? "ok\n" : "unavailable\n", status: result.http_status
  end

  def render_snapshot(result)
    probes = result.dependencies
    body = [
      "status: #{public_status(result.ok?)}",
      "startup: #{public_status(probes.fetch("startup").fetch(:status) == "ok")}",
      "liveness: #{public_status(probes.fetch("liveness").fetch(:status) == "ok")}",
      "readiness: #{public_status(probes.fetch("readiness").fetch(:status) == "ok")}",
    ].join("\n")

    render plain: "#{body}\n", status: result.http_status
  end

  private

  # A health response is a verdict about this instance at this instant, so a stored copy is a
  # stale verdict: a cached 200 keeps an orchestrator sending traffic to an instance that has
  # since failed its readiness probe, and a cached 503 keeps traffic away from one that has
  # recovered. Rails otherwise defaults these to `max-age=0, private, must-revalidate`, which
  # permits storage. Applied as a callback rather than inside the render helpers so every
  # health response carries the header.
  def disable_health_response_cache
    response.set_header("Cache-Control", "no-store")
  end

  def public_status(ok)
    ok ? "ok" : "unavailable"
  end

  def health_profile
    unless self.class.const_defined?(:HEALTH_PROFILE, false)
      raise Health::MissingProfileError, "#{self.class.name} must define its own HEALTH_PROFILE"
    end

    self.class.const_get(:HEALTH_PROFILE, false)
  end
end

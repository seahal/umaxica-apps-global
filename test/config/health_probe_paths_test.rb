# typed: false
# frozen_string_literal: true

require "test_helper"

# Host Authorization is the DNS rebinding defence. `HealthProbePaths` is the list of request paths
# that give it up, so this test pins both halves: the four probes must get through with a Host the
# application does not otherwise accept, and nothing else may.
#
# The assertions drive the real ActionDispatch::HostAuthorization middleware rather than calling the
# predicate directly, because the predicate being correct is not the same claim as the exemption
# actually working. `config/environments/production.rb` wires the same `HealthProbePaths.probe?` into
# `config.host_authorization`; the test environment sets no `config.hosts` at all, so the middleware
# is inert there and has to be built explicitly to be observed.
class HealthProbePathsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  ALLOWED_HOST = "www.umaxica.app"

  # What an orchestrator probe looks like: a container name or pod IP, deliberately absent from
  # config.hosts, because listing it would let anyone in under that name.
  PROBE_HOST = "base-app-7d9f4c"

  test "the exempt path set is exactly the four probes the router mounts" do
    assert_equal(
      ["/health", "/health/livenesses", "/health/readinesses", "/health/startups"],
      HealthProbePaths::PATHS,
    )
  end

  test "every mounted probe path reaches the application from an unauthorized host" do
    HealthProbePaths::PATHS.each do |path|
      status, _headers, body = call_middleware(path, host: PROBE_HOST)

      assert_equal 200, status, "#{path} must answer an internal probe, not Host Authorization"
      assert_equal ["reached the app"], body
    end
  end

  # The point of exact matching. Each of these lives under or near /health and must still be refused.
  test "a path outside the set is refused from an unauthorized host" do
    ["/healthcheck", "/health/foo", "/health/livenesses/extra", "/health/", "/groups"].each do |path|
      status, _headers, _body = call_middleware(path, host: PROBE_HOST)

      assert_equal 403, status, "#{path} must not inherit the health probe exemption"
    end
  end

  # A future `/health/diagnostics` must not become exempt merely by being added to the router.
  test "a new path under /health does not inherit the exemption" do
    status, = call_middleware("/health/diagnostics", host: PROBE_HOST)

    assert_equal 403, status
  end

  test "an authorized host reaches the application on any path" do
    ["/health", "/health/foo", "/groups"].each do |path|
      status, = call_middleware(path, host: ALLOWED_HOST)

      assert_equal 200, status, "#{path} must be served normally for an authorized host"
    end
  end

  private

  def call_middleware(path, host:)
    middleware.call(
      Rack::MockRequest.env_for("http://#{host}#{path}", "HTTP_HOST" => host),
    )
  end

  def middleware
    ActionDispatch::HostAuthorization.new(
      ->(_env) { [200, { "content-type" => "text/plain" }, ["reached the app"]] },
      [ALLOWED_HOST],
      exclude: ->(request) { HealthProbePaths.probe?(request) },
    )
  end
end

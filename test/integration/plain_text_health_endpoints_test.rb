# frozen_string_literal: true

require "test_helper"

class PlainTextHealthEndpointsTest < ActionDispatch::IntegrationTest
  test "health endpoints expose the resourceful plain text contract without authentication or redirects" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    {
      "/health" => "status: ok\nstartup: ok\nliveness: ok\nreadiness: ok\n",
      "/health/startups" => "ok\n",
      "/health/livenesses" => "ok\n",
      "/health/readinesses" => "ok\n",
    }.each do |path, expected_body|
      get path

      assert_response :success
      assert_equal "text/plain", response.media_type
      assert_equal "utf-8", response.charset
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_equal expected_body, response.body
      assert_not_predicate response, :redirect?
      assert_nil response.headers["Location"]
    end
  end

  test "health endpoints never negotiate json or html representations" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    ["/health", "/health/startups", "/health/livenesses", "/health/readinesses"].each do |path|
      ["application/json", "text/html"].each do |accept|
        get path, headers: { "Accept" => accept }

        assert_includes [200, 503], response.status
        assert_equal "text/plain", response.media_type
        assert_equal "utf-8", response.charset
      end
    end

    get "/health.json"

    assert_response :not_found

    get "/health/readinesses.txt"

    assert_response :not_found
  end

  test "readiness returns service unavailable when a required dependency fails" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")
    result = Health::CheckResult.new(
      check: :readiness,
      status: :unready,
      surface: Health::Profiles::SignApp.surface_label,
      dependencies: { "database" => "failed" },
    )

    Health::ReadinessCheck.stub(:call, result) do
      get "/health/readinesses"
    end

    assert_response :service_unavailable
    assert_equal "text/plain", response.media_type
    assert_equal "unavailable\n", response.body
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "liveness stays successful when external dependencies fail" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    Health::ReadinessCheck.stub(:call, ->(*) { raise StandardError, "readiness dependency touched" }) do
      ActiveRecord::Base.stub(:connection, -> { raise StandardError, "database touched" }) do
        get "/health/livenesses"
      end
    end

    assert_response :success
    assert_equal "ok\n", response.body
  end
end

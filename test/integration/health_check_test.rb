# typed: false
# frozen_string_literal: true

require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")
  end

  test "readiness returns ok when dependencies are healthy" do
    result = Health::CheckResult.new(
      check: :readiness,
      status: :ok,
      surface: "sign app",
      dependencies: { "database" => "ok" },
    )

    Health::ReadinessCheck.stub(:call, result) do
      get "/health/readiness?ri=jp"
    end

    assert_response :success
    assert_equal "ok", response.parsed_body["status"]
    assert_equal "readiness", response.parsed_body["check"]
    assert_equal({ "database" => "ok" }, response.parsed_body["dependencies"])
  end

  test "readiness returns unavailable when dependencies fail" do
    result = Health::CheckResult.new(
      check: :readiness,
      status: :unready,
      surface: "sign app",
      dependencies: { "database" => "failed" },
    )

    Health::ReadinessCheck.stub(:call, result) do
      get "/health/readiness?ri=jp"
    end

    assert_response :service_unavailable
    assert_equal "unavailable", response.parsed_body["status"]
    assert_equal({ "database" => "failed" }, response.parsed_body["dependencies"])
  end

  test "startup reports unavailable when Rails is not initialized" do
    Rails.application.stub(:initialized?, false) do
      get "/health/startup?ri=jp"
    end

    assert_response :service_unavailable
    assert_equal "unavailable", response.parsed_body["status"]
    assert_equal "starting", response.parsed_body.dig("details", "status")
    assert_nil response.parsed_body.dig("details", "surface")
  end

  test "health snapshot HTML does not expose surface" do
    result = Health::CheckResult.new(
      check: :health,
      status: :ok,
      surface: "sign app",
      dependencies: {
        "liveness" => { status: "ok" },
        "readiness" => { status: "ok" },
        "startup" => { status: "ok" },
      },
    )

    Health::SnapshotCheck.stub(:call, result) do
      get "/health?ri=jp"
    end

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_no_match(/Surface/i, response.body)
  end

  test "health snapshot does not serve json" do
    get "/health.json?ri=jp"

    assert_response :not_acceptable

    get "/health", headers: { "Accept" => "application/json" }

    assert_response :not_acceptable
  end
end

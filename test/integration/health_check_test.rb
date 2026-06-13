# typed: false
# frozen_string_literal: true

require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
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
  end
end

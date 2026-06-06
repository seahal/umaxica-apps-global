# typed: false
# frozen_string_literal: true

require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
  end

  test "readiness returns ok when dependencies are healthy" do
    report = Health::Report.aggregate(
      profile: Health::Profiles::SignApp,
      probe: :ready,
      checks: [Health::Check::Result.new(kind: :database, status: :ok)],
    )

    Health::Readiness.stub(:call, report) do
      get "/health/ready?ri=jp"
    end

    assert_response :success
    assert_equal "ok", response.parsed_body["status"]
  end

  test "readiness returns unavailable when dependencies fail" do
    report = Health::Report.aggregate(
      profile: Health::Profiles::SignApp,
      probe: :ready,
      checks: [Health::Check::Result.new(kind: :database, status: :unready)],
    )

    Health::Readiness.stub(:call, report) do
      get "/health/ready?ri=jp"
    end

    assert_response :service_unavailable
    assert_equal "unready", response.parsed_body["status"]
  end

  test "startup reports starting when Rails is not initialized" do
    Rails.application.stub(:initialized?, false) do
      get "/health/startup?ri=jp"
    end

    assert_response :service_unavailable
    assert_equal "starting", response.parsed_body["status"]
  end
end

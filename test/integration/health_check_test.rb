# typed: false
# frozen_string_literal: true

require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  # Use the sign.app health endpoint for integration testing of the Health concern.
  # The concern logic is shared across all health controllers.

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
  end

  test "returns 200 OK when all dependencies are healthy" do
    get sign_app_health_url(ri: "jp")

    assert_response :success
    assert_includes response.body, "OK"
  end

  test "returns 503 UNHEALTHY when a database writer connection fails" do
    inject_health_method(:check_databases) do |errors|
      errors << "Database PrincipalRecord(writing) failed: connection refused"
    end

    get(sign_app_health_url(ri: "jp"))

    assert_response :service_unavailable
    assert_includes response.body, "UNHEALTHY"
  ensure
    remove_health_method(:check_databases)
  end

  test "returns 503 UNHEALTHY when a database reader connection fails" do
    inject_health_method(:check_databases) do |errors|
      errors << "Database PrincipalRecord(reading) failed: replica unavailable"
    end

    get(sign_app_health_url(ri: "jp"))

    assert_response :service_unavailable
    assert_includes response.body, "UNHEALTHY"
  ensure
    remove_health_method(:check_databases)
  end

  test "returns 503 UNHEALTHY when Redis connection fails" do
    inject_health_method(:check_redis) do |errors|
      errors << "Redis connection failed: Redis down"
    end

    get(sign_app_health_url(ri: "jp"))

    assert_response :service_unavailable
    assert_includes response.body, "UNHEALTHY"
  ensure
    remove_health_method(:check_redis)
  end

  test "returns 503 UNHEALTHY when multiple dependencies fail" do
    inject_health_method(:check_dependencies) do
      [
        "Database PrincipalRecord(writing) failed: db down",
        "Redis connection failed: Redis down",
      ]
    end

    get(sign_app_health_url(ri: "jp"))

    assert_response :service_unavailable
    assert_includes response.body, "UNHEALTHY"
  ensure
    remove_health_method(:check_dependencies)
  end

  test "returns 503 BOOTING when Rails is not initialized" do
    Rails.application.stub(:initialized?, false) do
      get sign_app_health_url(ri: "jp")
    end

    assert_response :service_unavailable
    assert_includes response.body, "BOOTING"
  end

  test "returns 503 ERROR when an unexpected exception occurs" do
    inject_health_method(:check_dependencies) { raise RuntimeError, "unexpected" }

    get(sign_app_health_url(ri: "jp"))

    assert_response :service_unavailable
    assert_includes response.body, "ERROR"
  ensure
    remove_health_method(:check_dependencies)
  end

  private

  def inject_health_method(method_name, &)
    Sign::App::HealthsController.send(:define_method, method_name, &)
  end

  def remove_health_method(method_name)
    Sign::App::HealthsController.send(:remove_method, method_name) if Sign::App::HealthsController.private_method_defined?(
      method_name, false,
    ) || Sign::App::HealthsController.method_defined?(method_name, false)
  end
end

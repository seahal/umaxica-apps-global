# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# Validates the machine-readable health probes against each surface description.
#
# The aggregate `GET /health` is absent on purpose: `HealthCheckRendering#render_snapshot` answers
# `406` to a non-HTML `Accept` and otherwise renders HTML, so it is not part of a JSON contract.
# That is asserted here too, because the previous description claimed it returned
# `application/json`.
class OpenapiHealthContractTest < ActionDispatch::IntegrationTest
  include OpenapiContract

  openapi_surface :app

  PROBES = %w(liveness readiness startup).freeze

  PROBES.each do |probe|
    test "GET /health/#{probe} conforms to the app description" do
      get "/health/#{probe}", headers: host_headers(core_host).merge("Accept" => "application/json")

      assert_response :success
      assert_openapi_conform 200
    end
  end

  test "a probe names the surface that answered" do
    get "/health/liveness", headers: host_headers(core_host).merge("Accept" => "application/json")

    assert_response :success
    # Added by commit 5a5b0f1e2 and previously undescribed: one process answers on many hostnames
    # and the probe bodies were otherwise identical.
    assert_equal "core/app", response.parsed_body.fetch("namespace")
    assert_openapi_conform 200
  end

  test "the aggregate snapshot is not a JSON endpoint" do
    get "/health", headers: host_headers(core_host).merge("Accept" => "application/json")

    assert_response :not_acceptable
    assert_empty response.body
  end

  private

  def core_host
    ENV.fetch("PRIVATE_CORE_SERVICE_URL")
  end
end

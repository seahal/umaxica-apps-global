# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# Validates the machine-readable health probes against each surface description.
#
# The aggregate `GET /health` is absent on purpose: it is a four-line plain-text snapshot for
# operators, not part of the probe contract described here.
class OpenapiHealthContractTest < ActionDispatch::IntegrationTest
  include OpenapiContract

  openapi_surface :app

  PROBES = %w(livenesses readinesses startups).freeze

  PROBES.each do |probe|
    test "GET /health/#{probe} conforms to the app description" do
      get "/health/#{probe}", headers: host_headers(core_host)

      assert_response :success
      assert_openapi_conform 200
    end
  end

  test "a probe answers from the host that was routed" do
    get "/health/livenesses", headers: host_headers(core_host)

    assert_response :success
    assert_equal "ok\n", response.body
    assert_openapi_conform 200
  end

  test "the aggregate snapshot is not a JSON endpoint" do
    get "/health", headers: host_headers(core_host).merge("Accept" => "application/json")

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "status: ok\nstartup: ok\nliveness: ok\nreadiness: ok\n", response.body
  end

  private

  def core_host
    ENV.fetch("PRIVATE_CORE_SERVICE_URL")
  end
end

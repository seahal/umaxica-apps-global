# typed: false
# frozen_string_literal: true

require "test_helper"

class EidRouteContractTest < ActionDispatch::IntegrationTest
  EID_HOST = ENV.fetch("PRIVATE_EID_SERVICE_URL", "eid.net.localhost")

  test "eid host routes only the dedicated surface contract" do
    {
      "/" => ["eid/net/roots", "index"],
      "/health" => ["eid/net/healths", "show"],
      "/health/liveness" => ["eid/net/health/livenesses", "show"],
      "/health/readiness" => ["eid/net/health/readinesses", "show"],
      "/health/startup" => ["eid/net/health/startups", "show"],
      "/revision" => ["eid/net/revisions", "show"],
      "/api/v0/health.json" => ["eid/net/api/v0/healths", "show"],
      "/api/v0/revision.json" => ["eid/net/api/v0/revisions", "show"],
      "/api/v0/resources/example-eid" => ["eid/net/api/v0/resources", "show"],
    }.each do |path, (controller, action)|
      recognized = Rails.application.routes.recognize_path("http://#{EID_HOST}#{path}", method: :get)

      assert_equal controller, recognized[:controller], path
      assert_equal action, recognized[:action], path
    end
  end

  test "eid resource route is not exposed through another surface host" do
    error =
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{ENV.fetch("PRIVATE_INFO_SERVICE_URL", "info.app.localhost")}/api/v0/resources/example-eid",
          method: :get,
        )
      end

    assert_match(/No route matches/, error.message)
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class EdgeHealthRoutesTest < ActionDispatch::IntegrationTest
  test "apex edge health routes resolve" do
    [
      ENV.fetch("APEX_CORPORATE_URL", "www.com.localhost"),
      ENV.fetch("APEX_SERVICE_URL", "www.app.localhost"),
      ENV.fetch("APEX_STAFF_URL", "www.org.localhost"),
    ].each do |host|
      get "/edge/v0/health", headers: { "Host" => host }

      assert_response :success
      assert_equal "OK", response.parsed_body["status"]
    end
  end

  test "sign com edge health route resolves" do
    get sign_com_edge_v0_health_url(host: ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"), ri: "jp")

    assert_response :success
    assert_equal "OK", response.parsed_body["status"]
  end
end

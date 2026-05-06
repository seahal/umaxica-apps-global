# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::Com::ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  test "GET /configuration returns success" do
    host! ENV.fetch("APEX_CORPORATE_URL", "www.com.localhost")

    get apex_com_configuration_url(ri: "jp")

    assert_response :success
  end
end

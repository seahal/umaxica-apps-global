# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Base::Com::FullAccessGateTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "com-full-access@example.com")
  end

  test "dashboard redirects authenticated unselected visitor to selector" do
    get base_com_dashboard_url(host: @host, ri: "jp"), headers: as_visitor_headers(@visitor, host: @host)

    assert_redirected_to base_com_selector_path(ri: "jp")
  end

  test "dashboard requests selection as json when context is missing" do
    get base_com_dashboard_url(host: @host, ri: "jp"), headers: as_visitor_headers(
      @visitor,
      host: @host,
    ), as: :json

    assert_response :forbidden
    assert_equal "selection_required", response.parsed_body.fetch("status")
  end
end

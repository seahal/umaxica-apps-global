# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Base::Org::FullAccessGateTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
  end

  test "dashboard redirects authenticated unselected operator to selector" do
    get base_org_dashboard_url(host: @host, ri: "jp"), headers: as_staff_headers(@operator, host: @host)

    assert_redirected_to base_org_selector_path(ri: "jp")
  end

  test "dashboard requests selection as json when context is missing" do
    get base_org_dashboard_url(host: @host, ri: "jp"), headers: as_staff_headers(
      @operator,
      host: @host,
    ), as: :json

    assert_response :forbidden
    assert_equal "selection_required", response.parsed_body.fetch("status")
  end
end

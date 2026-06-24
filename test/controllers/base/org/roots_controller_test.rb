# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("BASE_STAFF_URL", "base.org.localhost")
    @operator = operators(:one)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    satisfy_staff_verification(@token)
  end

  test "renders anonymous root" do
    host! @host

    get base_org_root_url(ri: "jp")

    assert_response :success
    assert_select "h1", text: "Base Org"
  end

  test "redirects signed-in operator to dashboard" do
    host! @host

    get base_org_root_url(ri: "jp"),
        headers: as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)

    assert_response :redirect
    assert_redirected_to base_org_dashboard_url(ri: "jp", host: @host)
  end
end

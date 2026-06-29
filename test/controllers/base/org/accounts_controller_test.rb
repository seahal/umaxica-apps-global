# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Base::Org::AccountsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = configured_host(:base_staff)
    @staff = operators(:one)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @staff)
  end

  test "index renders" do
    get base_org_accounts_url(ri: "jp", host: @host), headers: as_staff_headers(@staff, host: @host)

    assert_response :success
  end

  test "show resolves by public_id" do
    get "/accounts/#{@bootstrap.account.public_id}?ri=jp", headers: as_staff_headers(@staff, host: @host)

    assert_response :success
  end

  test "unknown public_id returns 404" do
    get "/accounts/unknown-account?ri=jp", headers: as_staff_headers(@staff, host: @host)

    assert_response :not_found
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Org::AccountsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
    @bootstrap = AcmeSelectorBootstrapAuthority.call(surface: :org, principal: @staff)
  end

  test "index renders" do
    get acme_org_accounts_url(ri: "jp", host: @host), headers: as_staff_headers(@staff, host: @host)

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

# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_corporate)
    @visitor = create_verified_visitor_with_email(email_address: "com-account@example.com")
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :com, principal: @visitor)
  end

  test "index renders" do
    get base_com_accounts_url(ri: "jp", host: @host), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :success
  end

  test "show resolves by public_id" do
    get "/accounts/#{@bootstrap.account.public_id}?ri=jp", headers: as_visitor_headers(@visitor, host: @host)

    assert_response :success
  end

  test "unknown public_id returns 404" do
    get "/accounts/unknown-account?ri=jp", headers: as_visitor_headers(@visitor, host: @host)

    assert_response :not_found
  end
end

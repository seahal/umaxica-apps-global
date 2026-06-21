# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "com-account@example.com")
  end

  test "unauthenticated cannot access account" do
    get acme_com_account_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :redirect
  end

  test "index delegates to show" do
    get acme_com_account_url(ri: "jp", host: @host), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :success
  end

  test "edit renders" do
    get edit_acme_com_account_url(ri: "jp", host: @host), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :success
  end

  test "update redirects" do
    patch acme_com_account_url(ri: "jp", host: @host), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :see_other
    assert_redirected_to acme_com_account_url(ri: "jp", host: @host)
  end
end

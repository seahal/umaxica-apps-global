# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::SignInsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
  end

  test "should get new" do
    get new_sign_org_sign_in_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
  end

  test "renders local authentication links only" do
    get new_sign_org_sign_in_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success

    query = { ri: "jp" }

    assert_select "a[href=?]", new_sign_org_in_passkey_path(query)
    assert_select "a[href=?]", new_sign_org_in_secret_credential_path(query)
    assert_select "form[action*=?]", "/social/auth/", count: 0
    assert_select "form[action*=?]", "/auth/google", count: 0
    assert_select "form[action*=?]", "/auth/apple", count: 0
  end

  test "authentication links carry pt" do
    pt = Base64.urlsafe_encode64("https://id.umaxica.org/settings/sessions?ri=jp", padding: false)

    get new_sign_org_sign_in_url(ri: "jp", pt: pt), headers: { "Host" => @host }

    assert_response :success
    assert_select "a[href=?]", new_sign_org_in_passkey_path(ri: "jp")
    assert_select "a[href=?]", new_sign_org_in_secret_credential_path(ri: "jp")
  end

  test "does not render sign up link on sign in page" do
    get new_sign_org_sign_in_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
    assert_select "a[href=?]", new_sign_org_sign_up_path(ri: "jp"), count: 0
  end

  test "renders back to root link" do
    get new_sign_org_sign_in_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success

    assert_select "a[href=?]", acme_org_root_path(ri: "jp")
  end

  test "redirects to dashboard when logged in" do
    staff = operators(:one)

    get new_sign_org_sign_in_url(ri: "jp"), headers: as_staff_headers(staff, host: @host)

    assert_response :redirect
    assert_redirected_to acme_org_dashboard_url(ri: "jp", host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"))
  end
end

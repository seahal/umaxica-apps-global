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

  test "renders authentication links" do
    with_env("ORG_GOOGLE_SIGNIN_ENABLED" => "true") do
      get new_sign_org_sign_in_url(ri: "jp"), headers: { "Host" => @host }
    end

    assert_response :success

    query = { ri: "jp" }

    assert_select "a[href=?]", new_sign_org_in_passkey_path(query)
    assert_select "a[href=?]", new_sign_org_in_secret_credential_path(query)
    assert_select "form[action=?]", continue_sign_org_social_authentication_path(query.merge(provider: "google_org"))
  end

  test "does not render google signin when org google signin flag is off" do
    with_env("ORG_GOOGLE_SIGNIN_ENABLED" => "false") do
      get new_sign_org_sign_in_url(ri: "jp"), headers: { "Host" => @host }
    end

    assert_response :success
    assert_select "form[action=?]", continue_sign_org_social_authentication_path(provider: "google_org", ri: "jp"),
                  count: 0
  end

  test "authentication links carry pt" do
    pt = Base64.urlsafe_encode64("https://id.umaxica.org/configuration/sessions?ri=jp", padding: false)

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
    assert_redirected_to sign_org_dashboard_url(ri: "jp")
  end

  private

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end

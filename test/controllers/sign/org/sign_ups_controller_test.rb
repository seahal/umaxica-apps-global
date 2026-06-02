# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::SignUpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
  end

  test "should get new" do
    get new_sign_org_sign_up_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
  end

  test "does not show registration method choices" do
    with_env("ORG_GOOGLE_SIGNUP_ENABLED" => "false") do
      get new_sign_org_sign_up_url(ri: "jp"), headers: { "Host" => @host }
    end

    assert_response :success
    assert_select "[data-test-id=?]", "registration-method", count: 0
    assert_select "a[href=?]", "/sign/up/email/new?ri=jp", count: 0
    assert_select "form[action*=?]", "/social/auth/google", count: 0
    assert_select "form[action*=?]", "/social/auth/apple", count: 0
  end

  test "shows temporary google signup button only when signup flag is on" do
    with_env("ORG_GOOGLE_SIGNUP_ENABLED" => "true") do
      get new_sign_org_sign_up_url(ri: "jp"), headers: { "Host" => @host }
    end

    assert_response :success
    assert_select "form[action=?]", signup_sign_org_social_authentication_path(provider: "google_org", ri: "jp")
  end

  test "renders recruit contact and home links" do
    get new_sign_org_sign_up_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success

    acme_host = ENV["ACME_CORPORATE_URL"].presence || "www.com.localhost"

    assert_select "div a[href^=?]", "http://#{acme_host}/",
                  text: I18n.t("sign.org.ups.new.recruit_link_text")

    link = css_select("div a").find { |a| a.text == I18n.t("sign.org.ups.new.recruit_link_text") }

    assert_not_nil link,
                   "Could not find link with text: #{I18n.t("sign.org.ups.new.recruit_link_text").inspect}"
    href = link["href"]

    assert_match(/ri=jp/, href)
  end

  test "direct app-style email sign up route is not available" do
    get "/sign/up/email/new?ri=jp", headers: { "Host" => @host }

    assert_response :not_found
  end

  test "direct app-style telephone sign up route is not available" do
    get "/sign/up/telephone/new?ri=jp", headers: { "Host" => @host }

    assert_response :not_found
  end

  test "legacy invitation email sign up routes are not available" do
    get "/sign/up/invitations/emails/new?ri=jp", headers: { "Host" => @host }

    assert_response :not_found

    post "/sign/up/invitations/emails?ri=jp", headers: { "Host" => @host }

    assert_response :not_found

    get "/sign/up/invitations/emails/invite-code/edit?ri=jp", headers: { "Host" => @host }

    assert_response :not_found

    patch "/sign/up/invitations/emails/invite-code?ri=jp", headers: { "Host" => @host }

    assert_response :not_found
  end

  test "rejects when logged in" do
    staff = operators(:one)

    get new_sign_org_sign_up_url(ri: "jp"), headers: as_staff_headers(staff, host: @host)

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

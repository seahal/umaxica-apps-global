# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::SignUpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
  end

  test "shows email and telephone registration methods" do
    get new_sign_com_sign_up_url(ct: "dr", ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "[data-test-id=?]", "registration-method", count: 2
    assert_select "a[href=?]", new_sign_com_up_email_path(ct: "dr", ri: "jp"), count: 1
    assert_select "a[href=?]", new_sign_com_up_telephone_path(ct: "dr", ri: "jp"), count: 1
  end

  test "does not show social login buttons when flag is off" do
    get new_sign_com_sign_up_url(ct: "dr", ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "form[action*=?]", "/social/auth/google_app/continue", count: 0
    assert_select "form[action*=?]", "/social/auth/apple/continue", count: 0
    assert_select "form[action*=?]", "/social/auth/google", count: 0
    assert_select "form[action*=?]", "/auth/google", count: 0
  end

  test "does not show temporary google signup button when legacy flag is on" do
    with_env("COM_#{"GOOGLE"}_SIGNUP_ENABLED" => "true") do
      get new_sign_com_sign_up_url(ct: "dr", ri: "jp"), headers: default_headers
    end

    assert_response :success
    assert_select "form[action*=?]", "/social/auth/google", count: 0
    assert_select "form[action*=?]", "/auth/google", count: 0
  end

  test "rejects when logged in" do
    visitor = create_verified_visitor_with_email(email_address: "com-up-logged-in@example.com")
    visitor.visitor_telephones.create!(
      number: "+15550002224",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    get new_sign_com_sign_up_url(ri: "jp"), headers: as_visitor_headers(visitor, host: host)

    assert_redirected_to acme_com_dashboard_url(ri: "jp", host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"))
  end

  test "checkpoint without active registration redirects to sign up start" do
    get sign_com_up_check_url(ri: "jp"), headers: default_headers

    assert_redirected_to new_sign_com_sign_up_url(ri: "jp")
    assert_equal I18n.t("sign.com.registration.session_missing"), flash[:alert]
  end

  private

  def default_headers
    { "Host" => host, "HTTPS" => "on" }
  end

  def host
    ENV["ID_CORPORATE_URL"] || "id.com.localhost"
  end

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end

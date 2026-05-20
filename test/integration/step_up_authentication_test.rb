# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class StepUpAuthenticationTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host

    @user = clients(:one)
    @token = ClientToken.create!(
      user: @user,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: "stepup_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
    )
    @token.update!(created_at: 1.hour.ago)

    @headers = {
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze

    ClientEmail.create!(
      user: @user,
      address: "stepup-auth-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
  end

  test "GET sensitive page redirects to verification when step-up is not satisfied" do
    get new_sign_app_configuration_emails_registration_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "configuration_email", query["scope"]
    assert_equal "jp", query["ri"]
    assert_predicate query["rt"], :present?
  end

  test "fresh sign-in token does not satisfy step-up without recorded step-up" do
    @token.update!(created_at: 1.minute.ago, last_step_up_at: nil, last_step_up_scope: nil)

    get sign_app_configuration_emails_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "configuration_email", query["scope"]
    assert_predicate query["rt"], :present?
  end

  test "POST sensitive action returns 401 when step-up is not satisfied" do
    post sign_app_configuration_emails_registration_url(ri: "jp"),
         params: { user_email: { address: "new@example.com" } },
         headers: @headers

    assert_response :unauthorized
    assert_equal Verification::Base::STEP_UP_REQUIRED_MESSAGE, response.body
  end

  test "scope mismatch redirects to verification" do
    @token.update!(last_step_up_at: 3.minutes.ago, last_step_up_scope: "withdrawal")

    get sign_app_configuration_emails_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "configuration_email", query["scope"]
    assert_predicate query["rt"], :present?
  end

  test "step-up older than 15 minutes redirects to verification" do
    @token.update!(last_step_up_at: 15.minutes.ago, last_step_up_scope: "configuration_email")

    get sign_app_configuration_emails_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal "/verification", uri.path
    assert_predicate Rack::Utils.parse_query(uri.query)["rt"], :present?
  end

  test "step-up within TTL and matching scope passes through" do
    satisfy_user_verification(@token)
    @token.update!(last_step_up_at: 10.minutes.ago, last_step_up_scope: "configuration_email")

    get sign_app_configuration_emails_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "HEAD sensitive page redirects to verification when step-up is not satisfied" do
    head new_sign_app_configuration_emails_registration_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "configuration_email", query["scope"]
    assert_equal "jp", query["ri"]
    assert_predicate query["rt"], :present?
  end

  test "HEAD step-up within TTL and matching scope passes through" do
    satisfy_user_verification(@token)
    @token.update!(last_step_up_at: 10.minutes.ago, last_step_up_scope: "configuration_email")

    head sign_app_configuration_emails_url(ri: "jp"), headers: @headers

    assert_response :success
  end
end

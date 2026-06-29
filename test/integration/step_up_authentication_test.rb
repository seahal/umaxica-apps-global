# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"
require "base64"

class StepUpAuthenticationTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
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
    get new_auth_app_settings_emails_registration_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/identity/emails/registration/new", uri.path
    assert_nil query["scope"]
    assert_equal "jp", query["ri"]
    assert_nil query["pt"]
  end

  test "fresh sign-in token does not satisfy step-up without recorded step-up" do
    @token.update!(created_at: 1.minute.ago, last_step_up_at: nil, last_step_up_scope: nil)

    get auth_app_settings_emails_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/identity/emails", uri.path
    assert_nil query["scope"]
    assert_nil query["pt"]
  end

  test "POST sensitive action returns 401 when step-up is not satisfied" do
    post auth_app_settings_emails_registration_url(ri: "jp"),
         params: { user_email: { address: "new@example.com" } },
         headers: @headers

    assert_response :gone
  end

  test "scope mismatch redirects to verification" do
    mark_step_up_satisfied!(@token, at: 3.minutes.ago, scope: "withdrawal")

    get auth_app_settings_emails_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/identity/emails", uri.path
    assert_nil query["scope"]
    assert_nil query["pt"]
  end

  test "step-up older than 15 minutes redirects to verification" do
    mark_step_up_satisfied!(@token, at: 15.minutes.ago, scope: "settings_email")

    get auth_app_settings_emails_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal "/identity/emails", uri.path
    assert_nil Rack::Utils.parse_query(uri.query)["pt"]
  end

  test "step-up within TTL and matching scope passes through" do
    satisfy_user_verification(@token)
    mark_step_up_satisfied!(@token, at: 10.minutes.ago, scope: "settings_email")

    get auth_app_settings_emails_url(ri: "jp"), headers: @headers

    assert_response :redirect
  end

  test "step-up satisfied on one session does not satisfy another" do
    satisfy_user_verification(@token)
    mark_step_up_satisfied!(@token, at: 10.minutes.ago, scope: "settings_email")

    other_token = ClientToken.create!(
      user: @user,
      user_token_status_id: ClientTokenStatus::NOTHING,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      public_id: "stepup_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
    )
    other_token.update!(created_at: 1.hour.ago)
    other_headers = @headers.merge("X-TEST-SESSION-PUBLIC-ID" => other_token.public_id)

    get auth_app_settings_emails_url(ri: "jp"), headers: other_headers

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal "/identity/emails", uri.path
  end

  test "mismatched session binding does not satisfy browser step-up" do
    satisfy_user_verification(@token)
    mark_step_up_satisfied!(@token, at: 10.minutes.ago, scope: "settings_email")
    @token.update!(last_step_up_session_public_id: "other-session")

    get auth_app_settings_emails_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal "/identity/emails", uri.path
  end

  test "revoked session does not retain step-up freshness" do
    satisfy_user_verification(@token)
    mark_step_up_satisfied!(@token, at: 10.minutes.ago, scope: "settings_email")
    @token.update!(discarded_at: 1.second.ago)

    get auth_app_settings_emails_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal "/identity/emails", uri.path
  end

  test "session reset clears step-up freshness" do
    satisfy_user_verification(@token)
    mark_step_up_satisfied!(@token, at: 10.minutes.ago, scope: "settings_email")
    @token.update!(last_step_up_at: nil, last_step_up_scope: nil, last_step_up_session_public_id: nil)

    get auth_app_settings_emails_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal "/identity/emails", uri.path
  end

  test "missing session binding does not satisfy browser step-up" do
    @token.update!(last_step_up_at: 10.minutes.ago, last_step_up_scope: "settings_email")

    get auth_app_settings_emails_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/identity/emails", uri.path
    assert_nil query["scope"]
  end

  test "HEAD sensitive page redirects to verification when step-up is not satisfied" do
    head new_auth_app_settings_emails_registration_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/identity/emails/registration/new", uri.path
    assert_nil query["scope"]
    assert_equal "jp", query["ri"]
    assert_nil query["pt"]
  end

  private

  def mark_step_up_satisfied!(token, at:, scope:, method: "passkey", aal: "aal2")
    token.update!(
      last_step_up_at: at,
      last_step_up_scope: scope,
      last_step_up_aal: aal,
      last_step_up_method: method,
      last_step_up_session_public_id: token.public_id,
    )
  end
end

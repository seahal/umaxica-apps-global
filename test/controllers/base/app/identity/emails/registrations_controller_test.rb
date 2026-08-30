# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::Identity::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_service)
    ensure_client_reference_records!
    @client = Client.create!(status_id: ClientStatus::NOTHING)
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "new renders the registration form" do
    get new_base_app_identity_emails_registration_url(ri: "jp", host: @host), headers: auth_headers

    assert_response :success
  end

  test "create sends a code and moves the client to the edit step" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: unique_address } },
         headers: auth_headers

    assert_response :redirect
    assert_includes response.location, "/identity/emails/registration/edit"
    assert_equal 1, @client.client_emails.reload.count
  end

  test "create re-renders the form when the address is malformed" do
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: "not-an-address" } },
         headers: auth_headers

    assert_response :unprocessable_content
    assert_equal 0, @client.client_emails.reload.count
  end

  test "edit renders the code form while the registration session is live" do
    start_registration!

    get edit_base_app_identity_emails_registration_url(ri: "jp", host: @host), headers: auth_headers

    assert_response :success
  end

  test "edit returns to the first step when no registration is in flight" do
    get edit_base_app_identity_emails_registration_url(ri: "jp", host: @host), headers: auth_headers

    assert_response :redirect
    assert_includes response.location, "/identity/emails/registration/new"
  end

  test "update re-renders the code form when the code is missing" do
    start_registration!

    patch base_app_identity_emails_registration_url(ri: "jp", host: @host),
          params: { user_email: { pass_code: "" } },
          headers: auth_headers

    assert_response :unprocessable_content
  end

  test "update re-renders the code form when the code does not match" do
    email = start_registration!

    patch base_app_identity_emails_registration_url(ri: "jp", host: @host),
          params: { user_email: { pass_code: "000000" } },
          headers: auth_headers

    assert_response :unprocessable_content
    assert_equal ClientEmailStatus::UNVERIFIED, email.reload.user_email_status_id
  end

  test "update returns to the first step when no registration is in flight" do
    patch base_app_identity_emails_registration_url(ri: "jp", host: @host),
          params: { user_email: { pass_code: "000000" } },
          headers: auth_headers

    assert_response :redirect
    assert_includes response.location, "/identity/emails/registration/new"
  end

  private

  def unique_address
    "app-added-#{SecureRandom.hex(6)}@example.com"
  end

  def start_registration!
    post base_app_identity_emails_registration_url(ri: "jp", host: @host),
         params: { user_email: { raw_address: unique_address } },
         headers: auth_headers

    assert_response :redirect
    @client.client_emails.reload.find_by(user_email_status_id: ClientEmailStatus::UNVERIFIED)
  end

  # Authentication and step-up material go into the integration cookie jar rather than a literal
  # Cookie header, so the Rails session cookie set by one request survives into the next one.
  def auth_headers
    return @auth_headers if @auth_headers

    headers = as_user_headers(@client, host: @host)
    token = authentication_harness_latest_token(@client)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    access_token = headers["Cookie"].to_s[/#{Regexp.escape(AuthenticationBase::ACCESS_COOKIE_KEY)}=([^;]+)/, 1]
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    cookies[ClientVerification.cookie_name] = raw_token

    @auth_headers = headers.except("Cookie", "HTTP_COOKIE")
  end

  def ensure_client_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    [
      ClientEmailStatus::UNVERIFIED,
      ClientEmailStatus::VERIFIED,
    ].each { |id| ClientEmailStatus.find_or_create_by!(id: id) }
  end

  # DAMP local helper copy for former shared test support.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || "verification",
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: ("step_up:app" if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end
end

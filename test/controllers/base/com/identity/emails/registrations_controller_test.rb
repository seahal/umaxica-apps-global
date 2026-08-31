# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::Identity::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_corporate)
    @visitor = create_verified_visitor_with_email(email_address: "com-mail-reg-#{SecureRandom.hex(4)}@example.com")
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "new renders the registration form" do
    get new_base_com_identity_emails_registration_url(ri: "jp", host: @host), headers: auth_headers

    assert_response :success
  end

  test "create sends a code and moves the visitor to the edit step" do
    before_count = @visitor.visitor_emails.count

    post base_com_identity_emails_registration_url(ri: "jp", host: @host),
         params: { visitor_email: { raw_address: unique_address } },
         headers: auth_headers

    assert_response :redirect
    assert_includes response.location, "/identity/emails/registration/edit"
    assert_equal before_count + 1, @visitor.visitor_emails.reload.count
  end

  test "create re-renders the form when the turnstile challenge fails" do
    TurnstileVerifierStub.challenge_response = { "success" => false }
    before_count = @visitor.visitor_emails.count

    post base_com_identity_emails_registration_url(ri: "jp", host: @host),
         params: { visitor_email: { raw_address: unique_address } },
         headers: auth_headers

    assert_response :unprocessable_content
    assert_equal before_count, @visitor.visitor_emails.reload.count
  end

  test "create re-renders the form when the address is malformed" do
    before_count = @visitor.visitor_emails.count

    post base_com_identity_emails_registration_url(ri: "jp", host: @host),
         params: { visitor_email: { raw_address: "not-an-address" } },
         headers: auth_headers

    assert_response :unprocessable_content
    assert_equal before_count, @visitor.visitor_emails.reload.count
  end

  test "edit renders the code form while the registration session is live" do
    start_registration!

    get edit_base_com_identity_emails_registration_url(ri: "jp", host: @host), headers: auth_headers

    assert_response :success
  end

  test "edit returns to the first step when no registration is in flight" do
    get edit_base_com_identity_emails_registration_url(ri: "jp", host: @host), headers: auth_headers

    assert_response :redirect
    assert_includes response.location, "/identity/emails/registration/new"
  end

  test "update re-renders the code form when the code is missing" do
    start_registration!

    patch base_com_identity_emails_registration_url(ri: "jp", host: @host),
          params: { visitor_email: { pass_code: "" } },
          headers: auth_headers

    assert_response :unprocessable_content
  end

  test "update re-renders the code form when the code does not match" do
    email = start_registration!

    patch base_com_identity_emails_registration_url(ri: "jp", host: @host),
          params: { visitor_email: { pass_code: "000000" } },
          headers: auth_headers

    assert_response :unprocessable_content
    assert_equal VisitorEmailStatus::UNVERIFIED, email.reload.visitor_email_status_id
  end

  test "update returns to the first step when no registration is in flight" do
    patch base_com_identity_emails_registration_url(ri: "jp", host: @host),
          params: { visitor_email: { pass_code: "000000" } },
          headers: auth_headers

    assert_response :redirect
    assert_includes response.location, "/identity/emails/registration/new"
  end

  private

  def unique_address
    "com-added-#{SecureRandom.hex(6)}@example.com"
  end

  def start_registration!
    post(
      base_com_identity_emails_registration_url(ri: "jp", host: @host),
      params: { visitor_email: { raw_address: unique_address } },
      headers: auth_headers,
    )

    assert_response :redirect
    @visitor.visitor_emails.reload.find_by(visitor_email_status_id: VisitorEmailStatus::UNVERIFIED)
  end

  # This flow gates on step_up_bootstrap_active?, so the session needs satisfied step-up material.
  # Authentication cookies go into the integration cookie jar rather than a literal Cookie header,
  # so the Rails session cookie set by one request survives into the next one.
  def auth_headers
    return @auth_headers if @auth_headers

    headers = as_visitor_headers(@visitor, host: @host)
    token = authentication_harness_latest_token(@visitor)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    access_token = headers["Cookie"].to_s[/#{Regexp.escape(AuthenticationBase::ACCESS_COOKIE_KEY)}=([^;]+)/, 1]
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    cookies[VisitorVerification.cookie_name] = raw_token

    @auth_headers = headers.except("Cookie", "HTTP_COOKIE")
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
      last_step_up_audience: ("step_up:com" if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end

  # DAMP local helper copy for former shared test support.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id,
      address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
    visitor.refresh_mfa_status! if visitor.respond_to?(:refresh_mfa_status!)
    visitor.reload
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    [
      VisitorEmailStatus::VERIFIED,
      VisitorEmailStatus::UNVERIFIED,
    ].each { |id| VisitorEmailStatus.find_or_create_by!(id: id) }
  end
end

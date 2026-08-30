# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Com::Identity::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_corporate)
    # A visitor without a verified telephone does not need a step-up session for this flow
    # (verification_required_action? is current_visitor&.verified_telephone?).
    @visitor = create_verified_visitor_with_email(email_address: "com-tel-reg-#{SecureRandom.hex(4)}@example.com")
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "new renders the registration form" do
    get new_base_com_identity_telephones_registration_url(ri: "jp", host: @host), headers: auth_headers

    assert_response :success
  end

  test "create sends a code and moves the visitor to the edit step" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: unique_number } },
         headers: auth_headers

    assert_redirected_to edit_base_com_identity_telephones_registration_path(ri: "jp")
    assert_equal 1, @visitor.visitor_telephones.count
    assert_equal VisitorTelephoneStatus::UNVERIFIED,
                 @visitor.visitor_telephones.first.visitor_telephone_status_id
  end

  test "create refuses the request when the turnstile challenge fails" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: unique_number } },
         headers: auth_headers

    assert_response :unprocessable_content
    assert_equal 0, @visitor.visitor_telephones.count
  end

  test "create re-renders the form when the number cannot be normalized" do
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: "not-a-telephone-number" } },
         headers: auth_headers

    assert_response :unprocessable_content
    assert_equal 0, @visitor.visitor_telephones.count
  end

  test "edit renders the code form while the registration session is live" do
    start_registration!

    get edit_base_com_identity_telephones_registration_url(ri: "jp", host: @host), headers: auth_headers

    assert_response :success
  end

  test "edit returns to the first step when no registration is in flight" do
    get edit_base_com_identity_telephones_registration_url(ri: "jp", host: @host), headers: auth_headers

    assert_redirected_to new_base_com_identity_telephones_registration_path(ri: "jp")
  end

  test "update verifies the submitted code and hands off to the telephone list" do
    telephone = start_registration!

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: current_otp_for(telephone) } },
          headers: auth_headers

    assert_redirected_to base_com_identity_telephones_url(
      ri: "jp",
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
    )
  end

  test "update re-renders the code form when the code is missing" do
    start_registration!

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "" } },
          headers: auth_headers

    assert_response :unprocessable_content
  end

  test "update re-renders the code form when the code does not match" do
    telephone = start_registration!

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "000000" } },
          headers: auth_headers

    assert_response :unprocessable_content
    assert_equal VisitorTelephoneStatus::UNVERIFIED, telephone.reload.visitor_telephone_status_id
  end

  test "update refuses the request when the turnstile challenge fails" do
    start_registration!
    TurnstileVerifierStub.challenge_response = { "success" => false }

    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "000000" } },
          headers: auth_headers

    assert_response :unprocessable_content
  end

  test "update returns to the first step when no registration is in flight" do
    patch base_com_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { user_telephone: { pass_code: "000000" } },
          headers: auth_headers

    assert_redirected_to new_base_com_identity_telephones_registration_path(ri: "jp")
  end

  private

  def unique_number
    "+8190#{format('%08d', SecureRandom.random_number(100_000_000))}"
  end

  def start_registration!
    post base_com_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { user_telephone: { raw_number: unique_number } },
         headers: auth_headers

    assert_redirected_to edit_base_com_identity_telephones_registration_path(ri: "jp")
    @visitor.visitor_telephones.reload.first
  end

  def current_otp_for(record)
    otp = record.reload.get_otp

    ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s
  end

  # The access cookie goes into the integration cookie jar rather than a literal Cookie header, so
  # the Rails session cookie set by one request survives into the next one.
  def auth_headers
    return @auth_headers if @auth_headers

    headers = as_visitor_headers(@visitor, host: @host)
    access_token = headers["Cookie"].to_s[/#{Regexp.escape(AuthenticationBase::ACCESS_COOKIE_KEY)}=([^;]+)/, 1]
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    @auth_headers = headers.except("Cookie", "HTTP_COOKIE")
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
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    [
      VisitorTelephoneStatus::UNVERIFIED,
      VisitorTelephoneStatus::VERIFIED,
      VisitorTelephoneStatus::NOTHING,
    ].each { |id| VisitorTelephoneStatus.find_or_create_by!(id: id) }
  end
end

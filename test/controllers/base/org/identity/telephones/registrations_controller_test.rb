# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Identity::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_staff)
    ensure_operator_reference_records!
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
    @token = OperatorToken.create!(
      staff: @operator,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "new renders the registration form and clears any earlier registration session" do
    get new_base_org_identity_telephones_registration_url(ri: "jp", host: @host), headers: step_up_headers

    assert_response :success
  end

  test "create sends a code and moves the operator to the edit step" do
    post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { staff_telephone: { raw_number: unique_number } },
         headers: step_up_headers

    assert_redirected_to edit_base_org_identity_telephones_registration_path(ri: "jp")
    assert_equal 1, @operator.staff_telephones.count
    assert_equal OperatorTelephoneStatus::UNVERIFIED,
                 @operator.staff_telephones.first.staff_telephone_status_id
  end

  test "create refuses the request when the turnstile challenge fails" do
    TurnstileVerifierStub.challenge_response = { "success" => false }

    post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { staff_telephone: { raw_number: unique_number } },
         headers: step_up_headers

    assert_response :unprocessable_content
    assert_equal 0, @operator.staff_telephones.count
  end

  test "create re-renders the form when the number cannot be normalized" do
    post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { staff_telephone: { raw_number: "not-a-telephone-number" } },
         headers: step_up_headers

    assert_response :unprocessable_content
    assert_equal 0, @operator.staff_telephones.count
  end

  test "edit renders the code form while the registration session is live" do
    start_registration!

    get edit_base_org_identity_telephones_registration_url(ri: "jp", host: @host), headers: step_up_headers

    assert_response :success
  end

  test "edit returns to the first step when no registration is in flight" do
    get edit_base_org_identity_telephones_registration_url(ri: "jp", host: @host), headers: step_up_headers

    assert_redirected_to new_base_org_identity_telephones_registration_path(ri: "jp")
  end

  test "update verifies the submitted code and finishes the registration" do
    telephone = start_registration!

    patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { staff_telephone: { pass_code: current_otp_for(telephone) } },
          headers: step_up_headers

    # sign/id only verifies the code here; the final account commit happens on acme/www, so the
    # contract this action owns is the hand-off redirect back to the telephone list.
    assert_redirected_to base_org_identity_telephones_url(
      ri: "jp",
      host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
    )
    assert_nil telephone.reload.get_otp&.fetch(:otp_private_key, nil)
  end

  test "update re-renders the code form when the code is missing" do
    start_registration!

    patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { staff_telephone: { pass_code: "" } },
          headers: step_up_headers

    assert_response :unprocessable_content
  end

  test "update re-renders the code form when the code does not match" do
    telephone = start_registration!

    patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { staff_telephone: { pass_code: "000000" } },
          headers: step_up_headers

    assert_response :unprocessable_content
    assert_equal OperatorTelephoneStatus::UNVERIFIED, telephone.reload.staff_telephone_status_id
  end

  test "update refuses the request when the turnstile challenge fails" do
    start_registration!
    TurnstileVerifierStub.challenge_response = { "success" => false }

    patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { staff_telephone: { pass_code: "000000" } },
          headers: step_up_headers

    assert_response :unprocessable_content
  end

  test "update returns to the first step when no registration is in flight" do
    patch base_org_identity_telephones_registration_url(ri: "jp", host: @host),
          params: { staff_telephone: { pass_code: "000000" } },
          headers: step_up_headers

    assert_redirected_to new_base_org_identity_telephones_registration_path(ri: "jp")
  end

  private

  def unique_number
    "+8190#{format('%08d', SecureRandom.random_number(100_000_000))}"
  end

  # Drives the real create action so the registration session and the OTP are produced the same way
  # the application produces them, rather than being assembled by the test.
  def start_registration!
    post base_org_identity_telephones_registration_url(ri: "jp", host: @host),
         params: { staff_telephone: { raw_number: unique_number } },
         headers: step_up_headers

    assert_redirected_to edit_base_org_identity_telephones_registration_path(ri: "jp")
    @operator.staff_telephones.reload.first
  end

  def current_otp_for(record)
    otp = record.reload.get_otp

    ROTP::HOTP.new(otp[:otp_private_key]).at(otp[:otp_counter]).to_s
  end

  # Authentication and step-up material go into the integration cookie jar rather than a literal
  # Cookie header, so the Rails session cookie set by one request survives into the next one.
  def step_up_headers
    return @step_up_headers if @step_up_headers

    mark_token_step_up_satisfied_for_test(@token, scope: "settings_telephone")
    _verification, raw_token = OperatorVerification.issue_for_token!(token: @token)
    headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
    access_token = headers["Cookie"].to_s[/#{Regexp.escape(AuthenticationBase::ACCESS_COOKIE_KEY)}=([^;]+)/, 1]
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    cookies[OperatorVerification.cookie_name] = raw_token

    @step_up_headers = headers.except("Cookie", "HTTP_COOKIE")
  end

  def ensure_operator_reference_records!
    OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    [
      OperatorTelephoneStatus::UNVERIFIED,
      OperatorTelephoneStatus::VERIFIED,
      OperatorTelephoneStatus::ACTIVE,
    ].each { |id| OperatorTelephoneStatus.find_or_create_by!(id: id) }
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
      last_step_up_audience: ("step_up:org" if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end
end

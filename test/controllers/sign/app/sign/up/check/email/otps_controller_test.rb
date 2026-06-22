# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Sign::Up::Check::Email::OtpsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    cookies["csrf_token"] = csrf_token_value
    Rails.configuration.x.rate_limit.fetch(:store).clear
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "create and update require a pending sign-up email flow" do
    post sign_app_sign_up_check_email_otp_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_includes response.body, "ticket is required"
  end

  test "update rejects malformed or wrong otp state" do
    start_pending_email_flow!("otp-state@example.com")

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { user_email: { pass_code: "" } },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.code_required")

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { user_email: { pass_code: "000000" } },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
  end

  test "update accepts a valid otp when submitted through the email form field" do
    user_email = start_pending_email_flow!("valid@example.com")
    pass_code = otp_code_for(user_email)

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { client_email: { pass_code: pass_code } },
          headers: { "Host" => @host }

    assert_response :redirect
  end

  test "update rejects a valid otp for a different sign-up ticket" do
    user_email = start_pending_email_flow!("wrong-ticket@example.com")
    pass_code = otp_code_for(user_email)

    start_pending_email_flow!("other-ticket@example.com")

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { user_email: { pass_code: pass_code } },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
  end

  test "update rejects a valid otp when the pending email changes" do
    user_email = start_pending_email_flow!("source@example.com")
    pass_code = otp_code_for(user_email)

    post sign_app_sign_up_email_url(ri: "jp"),
         params: {
           :user_email => {
             raw_address: "target@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response" => "test",
         },
         headers: { "Host" => @host }

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { user_email: { pass_code: pass_code } },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
  end

  test "update rejects expired sign-up otp" do
    user_email = start_pending_email_flow!("expired@example.com")
    pass_code = otp_code_for(user_email)

    travel SignOtpCeremony::OTP_EXPIRATION_MINUTES.minutes + 1.second do
      patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
            params: { user_email: { pass_code: pass_code } },
            headers: { "Host" => @host }
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.edit.session_expired")
  end

  test "update rejects malformed and blank sign-up otp values" do
    start_pending_email_flow!("malformed@example.com")

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { user_email: { pass_code: "" } },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.code_required")

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { user_email: { pass_code: "abc123" } },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
  end

  test "update rejects reused sign-up otp after consumption" do
    user_email = start_pending_email_flow!("consumed@example.com")
    pass_code = otp_code_for(user_email)

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { client_email: { pass_code: pass_code } },
          headers: { "Host" => @host }

    assert_response :redirect

    # After OTP is consumed the session no longer holds a pending unverified email,
    # so a second submission produces a session-expired error rather than invalid-code.
    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { client_email: { pass_code: pass_code } },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.edit.session_expired")
  end

  test "update rejects locked sign-up otp records" do
    user_email = start_pending_email_flow!("locked@example.com")
    pass_code = otp_code_for(user_email)
    user_email.update!(otp_attempts_count: OtpLockable::MAX_OTP_ATTEMPTS, locked_at: 1.minute.from_now)

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { user_email: { pass_code: pass_code } },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.invalid_code")
  end

  # Regression: the OTP step must resolve the pending email even when the
  # locator session payload no longer matches the ticket nonce (e.g. the cycle
  # was re-issued out of band). The step gate already falls back to the sequence
  # id to find the ticket; contact resolution has to use the same fallback or a
  # valid email sign-up is rejected as an expired session. google/apple flows do
  # not hit this email contact lookup, which is why only email broke.
  test "update accepts a valid otp when the locator nonce no longer matches the ticket" do
    user_email = start_pending_email_flow!("nonce-drift@example.com")
    pass_code = otp_code_for(user_email)

    cycle = ClientSignUpFlow.find_by!(
      pending_contact_type: "email",
      pending_contact_id: user_email.id,
    )
    # Drift the stored nonce so the locator session payload (still in the cookie)
    # can no longer match; only the sequence-id fallback can recover the ticket.
    cycle.update!(nonce_digest: ClientSignUpFlow.digest_nonce("out-of-band-nonce"))

    patch sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { client_email: { pass_code: pass_code } },
          headers: { "Host" => @host }

    assert_response :redirect
  end

  test "update emits rejected log for blank otp" do
    start_pending_email_flow!("log@example.com")
    logged =
      capture_email_log do
        patch(
          sign_app_sign_up_check_email_otp_url(ri: "jp"),
          params: { user_email: { pass_code: "" } },
          headers: { "Host" => @host },
        )
      end

    assert_includes logged, "sign.signup.email.otp.rejected"
    assert_includes logged, "otp_blank"
  end

  private

  def start_pending_email_flow!(email)
    post(
      sign_app_sign_up_email_url(ri: "jp"),
      params: {
        :user_email => {
          raw_address: email,
          confirm_policy: "1",
        },
        "cf-turnstile-response" => "test",
      },
      headers: { "Host" => @host },
    )

    assert_response :redirect
    ClientEmail.order(:created_at).last
  end

  def otp_code_for(user_email)
    otp_data = user_email.get_otp
    ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s
  end

  def capture_email_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end
end

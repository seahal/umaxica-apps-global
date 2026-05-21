# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::In::EmailsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    ActionMailer::Base.deliveries.clear
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenStatus.ensure_defaults!
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "get new renders email form" do
    get new_sign_com_in_email_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.authentication.email.new.page_title")
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, "turnstile.render"
  end

  test "post create with unknown email redirects to edit without visitor email session id" do
    assert_no_difference -> { ActionMailer::Base.deliveries.count } do
      post sign_com_in_email_url(ri: "jp"),
           params: {
             user_email: { address: "missing-visitor@example.com" },
             "cf-turnstile-response": "test",
           },
           headers: { "Host" => @host }

      assert_response :redirect
      assert_redirected_to %r{/sign/in/email/edit}
      assert_nil session[:user_email_authentication_id]
    end
  end

  test "post create with existing visitor email redirects to edit" do
    visitor = create_verified_visitor_with_email(email_address: "com-login-#{SecureRandom.hex(4)}@example.com")
    email = visitor.visitor_emails.last

    post sign_com_in_email_url(ri: "jp"),
         params: {
           user_email: { address: email.address },
           "cf-turnstile-response": "test",
         },
         headers: { "Host" => @host }

    assert_response :redirect
    assert_redirected_to %r{/sign/in/email/edit}
  end

  test "post create with invalid email format" do
    post sign_com_in_email_url(ri: "jp"),
         params: {
           user_email: { address: "invalid-email" },
           "cf-turnstile-response": "test",
         },
         headers: { "Host" => @host }

    assert_response :unprocessable_content
  end

  test "get edit redirects when session is expired" do
    get edit_sign_com_in_email_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect
    assert_redirected_to %r{/sign/in/email/new}
  end

  test "patch update with invalid OTP fails" do
    visitor = create_verified_visitor_with_email(email_address: "com-login-invalid@example.com")
    email = visitor.visitor_emails.last

    post sign_com_in_email_url(ri: "jp"),
         params: {
           user_email: { address: email.address },
           "cf-turnstile-response": "test",
         },
         headers: { "Host" => @host }

    patch sign_com_in_email_url(ri: "jp"),
          params: {
            user_email: { pass_code: "000000" },
          },
          headers: { "Host" => @host }

    assert_response :unprocessable_content
  end

  test "post create with cooldown active returns too many requests" do
    visitor = create_verified_visitor_with_email(email_address: "cooldown@example.com")
    email = visitor.visitor_emails.last

    post sign_com_in_email_url(ri: "jp"),
         params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    assert_response :redirect

    post sign_com_in_email_url(ri: "jp"),
         params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    assert_response :too_many_requests
  end

  test "email sign in locks after five invalid OTP attempts" do
    visitor = create_verified_visitor_with_email(email_address: "com-lockout@example.com")
    email = visitor.visitor_emails.last

    post sign_com_in_email_url(ri: "jp"),
         params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    Email::MAX_OTP_ATTEMPTS.times do
      patch sign_com_in_email_url(ri: "jp"),
            params: { user_email: { pass_code: "000000" } },
            headers: { "Host" => @host }
    end

    email.reload

    assert_response :unprocessable_content
    assert_predicate email, :locked?
    assert_operator email.lockout_expires_at, :>, Time.current
  end

  test "post create with locked visitor email does not send OTP" do
    visitor = create_verified_visitor_with_email(email_address: "com-create-locked@example.com")
    email = visitor.visitor_emails.last
    email.update!(locked_at: 5.minutes.from_now, otp_attempts_count: Email::MAX_OTP_ATTEMPTS)

    travel Common::OtpPolicy::SEND_COOLDOWN + 1.second do
      assert_no_difference -> { ActionMailer::Base.deliveries.count } do
        post sign_com_in_email_url(ri: "jp"),
             params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
             headers: { "Host" => @host }
      end
    end

    assert_response :redirect
    assert_redirected_to %r{/sign/in/email/edit}
  end

  test "post create with turnstile failure returns unprocessable content" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    post sign_com_in_email_url(ri: "jp"),
         params: { user_email: { address: "test@example.com" }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    assert_response :unprocessable_content
  end

  test "patch update success login" do
    visitor = create_verified_visitor_with_email(email_address: "success@example.com")
    email = visitor.visitor_emails.last

    post sign_com_in_email_url(ri: "jp"),
         params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    # Use a real OTP check by setting the OTP in DB
    email.store_otp("BASE32SECRET3232", 12_345, 15.minutes.from_now.to_i)
    hotp = ROTP::HOTP.new("BASE32SECRET3232")
    correct_code = hotp.at(12_345)

    patch sign_com_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: correct_code } },
          headers: { "Host" => @host }

    assert_response :redirect
  end

  test "patch update failure with JSON format" do
    visitor = create_verified_visitor_with_email(email_address: "json-fail@example.com")
    email = visitor.visitor_emails.last

    post sign_com_in_email_url(ri: "jp"),
         params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    patch sign_com_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: "000000" } },
          headers: { "Host" => @host, "Accept" => "application/json" }

    assert_response :unprocessable_content
    assert_not_empty response.parsed_body["error"]
  end

  private

  def create_verified_visitor_with_email(email_address:)
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor: visitor,
      address: email_address,
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: "1",
    )
    visitor
  end
end

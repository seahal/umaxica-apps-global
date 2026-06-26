# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Sign::In::EmailsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    host! ENV.fetch("SIGN_CORPORATE_URL", "sign.com.localhost")
    @host = ENV.fetch("SIGN_CORPORATE_URL", "sign.com.localhost")
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
    get new_sign_com_sign_in_email_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.authentication.email.new.page_title")
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, 'data-turnstile-mode-value="render"'
  end

  test "post create with unknown email redirects to edit without visitor email session id" do
    assert_no_difference -> { ActionMailer::Base.deliveries.count } do
      post sign_com_sign_in_email_url(ri: "jp"),
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

    post sign_com_sign_in_email_url(ri: "jp"),
         params: {
           user_email: { address: email.address },
           "cf-turnstile-response": "test",
         },
         headers: { "Host" => @host }

    assert_response :redirect
    assert_redirected_to %r{/sign/in/email/edit}
  end

  test "post create with invalid email format" do
    post sign_com_sign_in_email_url(ri: "jp"),
         params: {
           user_email: { address: "invalid-email" },
           "cf-turnstile-response": "test",
         },
         headers: { "Host" => @host }

    assert_response :unprocessable_content
  end

  test "get edit redirects when session is expired" do
    get edit_sign_com_sign_in_email_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect
    assert_redirected_to %r{/sign/in/email/new}
  end

  test "post create with cooldown active returns too many requests" do
    visitor = create_verified_visitor_with_email(email_address: "cooldown@example.com")
    email = visitor.visitor_emails.last

    post sign_com_sign_in_email_url(ri: "jp"),
         params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    assert_response :redirect

    post sign_com_sign_in_email_url(ri: "jp"),
         params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    assert_response :too_many_requests
  end

  test "post create with cooldown active returns login cooldown message" do
    visitor = create_verified_visitor_with_email(email_address: "cooldown-message@example.com")
    email = visitor.visitor_emails.last

    post sign_com_sign_in_email_url(ri: "jp"),
         params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    assert_response :redirect

    post sign_com_sign_in_email_url(ri: "jp"),
         params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    assert_response :too_many_requests
    assert_includes response.body, I18n.t("errors.messages.login_cooldown")
  end

  test "post create with locked visitor email does not send OTP" do
    visitor = create_verified_visitor_with_email(email_address: "com-create-locked@example.com")
    email = visitor.visitor_emails.last
    email.update!(locked_at: 5.minutes.from_now, otp_attempts_count: Email::MAX_OTP_ATTEMPTS)

    travel CommonOtpPolicy::SEND_COOLDOWN + 1.second do
      assert_no_difference -> { ActionMailer::Base.deliveries.count } do
        post sign_com_sign_in_email_url(ri: "jp"),
             params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
             headers: { "Host" => @host }
      end
    end

    assert_response :redirect
    assert_redirected_to %r{/sign/in/email/edit}
  end

  test "post create with turnstile failure returns unprocessable content" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    post sign_com_sign_in_email_url(ri: "jp"),
         params: { user_email: { address: "test@example.com" }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    assert_response :unprocessable_content
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

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
    CustomerStatus.find_or_create_by!(id: CustomerStatus::ACTIVE)
    CustomerVisibility.find_or_create_by!(id: CustomerVisibility::CUSTOMER)
    CustomerEmailStatus.find_or_create_by!(id: CustomerEmailStatus::VERIFIED)
    CustomerTelephoneStatus.find_or_create_by!(id: CustomerTelephoneStatus::VERIFIED)
    CustomerTokenKind.find_or_create_by!(id: CustomerTokenKind::BROWSER_WEB)
    CustomerTokenBindingMethod.find_or_create_by!(id: CustomerTokenBindingMethod::NOTHING)
    CustomerTokenBindingMethod.find_or_create_by!(id: CustomerTokenBindingMethod::LEGACY)
    CustomerTokenStatus.find_or_create_by!(id: CustomerTokenStatus::NOTHING)
    CustomerTokenDbscStatus.find_or_create_by!(id: CustomerTokenDbscStatus::NOTHING)
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "get new renders email form" do
    get new_sign_com_in_email_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
    assert_includes response.body, I18n.t("sign.app.authentication.email.new.page_title")
  end

  test "post create with unknown email redirects to edit without customer email session id" do
    assert_no_difference -> { ActionMailer::Base.deliveries.count } do
      post sign_com_in_email_url(ri: "jp"),
           params: {
             user_email: { address: "missing-customer@example.com" },
             "cf-turnstile-response": "test",
           },
           headers: { "Host" => @host }

      assert_response :redirect
      assert_redirected_to %r{/in/email/edit}
      assert_nil session[:user_email_authentication_id]
    end
  end

  test "post create with existing customer email redirects to edit" do
    customer = create_verified_customer_with_email(email_address: "com-login-#{SecureRandom.hex(4)}@example.com")
    email = customer.customer_emails.last

    post sign_com_in_email_url(ri: "jp"),
         params: {
           user_email: { address: email.address },
           "cf-turnstile-response": "test",
         },
         headers: { "Host" => @host }

    assert_response :redirect
    assert_redirected_to %r{/in/email/edit}
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
    assert_redirected_to %r{/in/email/new}
  end

  test "patch update with invalid OTP fails" do
    customer = create_verified_customer_with_email(email_address: "com-login-invalid@example.com")
    email = customer.customer_emails.last

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
    customer = create_verified_customer_with_email(email_address: "cooldown@example.com")
    email = customer.customer_emails.last

    post sign_com_in_email_url(ri: "jp"),
         params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    assert_response :redirect

    post sign_com_in_email_url(ri: "jp"),
         params: { user_email: { address: email.address }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    assert_response :too_many_requests
  end

  test "post create with turnstile failure returns unprocessable content" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    post sign_com_in_email_url(ri: "jp"),
         params: { user_email: { address: "test@example.com" }, "cf-turnstile-response": "test" },
         headers: { "Host" => @host }

    assert_response :unprocessable_content
  end

  test "patch update success login" do
    customer = create_verified_customer_with_email(email_address: "success@example.com")
    email = customer.customer_emails.last

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
    customer = create_verified_customer_with_email(email_address: "json-fail@example.com")
    email = customer.customer_emails.last

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

  def create_verified_customer_with_email(email_address:)
    customer = Customer.create!(status_id: CustomerStatus::ACTIVE, visibility_id: CustomerVisibility::CUSTOMER)
    CustomerEmail.create!(
      customer: customer,
      address: email_address,
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
      confirm_policy: "1",
    )
    customer
  end
end

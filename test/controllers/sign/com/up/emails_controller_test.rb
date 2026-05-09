# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Up::EmailsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    [1, 2, 3].each { |id| CustomerStatus.find_or_create_by!(id: id) }
    [0, 1, 2, 3].each { |id| CustomerVisibility.find_or_create_by!(id: id) }
    CustomerEmailStatus.find_or_create_by!(id: CustomerEmailStatus::VERIFIED)
    CustomerEmailStatus.find_or_create_by!(id: CustomerEmailStatus::UNVERIFIED_WITH_SIGN_UP)
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should get new" do
    get new_sign_com_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "h2", I18n.t("sign.com.registration.email.new.page_title")
    assert_no_match(/UMAXICA \(sign, app\)/, response.body)
  end

  test "collection get redirects to new email registration" do
    get sign_com_up_emails_url(ri: "jp", hotwire_spark: true, reload: "123"), headers: default_headers

    assert_response :redirect
    assert_includes response.location, "/sign/up/emails/new?ri=jp"
    assert_not_includes response.location, "hotwire_spark"
    assert_not_includes response.location, "reload"
  end

  test "includes navigation link back to sign in" do
    get new_sign_com_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "a[href=?]", new_sign_com_in_path(ri: "jp"), count: 1
  end

  test "create redirects to edit and allows edit page" do
    post sign_com_up_emails_url(ri: "jp"),
         params: {
           customer_email: {
             raw_address: "com-flow-step@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    follow_redirect!

    assert_response :success
    assert_match(%r{/sign/up/emails/[^/]+/edit}, path)
  end

  test "create with existing email still redirects and does not create a new record" do
    customer = Customer.create!(status_id: CustomerStatus::ACTIVE, visibility_id: CustomerVisibility::CUSTOMER)
    existing_email = CustomerEmail.create!(
      customer: customer,
      address: "com-existing-signup@example.com",
      confirm_policy: "1",
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
    )

    assert_no_difference("Customer.count") do
      assert_no_difference("CustomerEmail.count") do
        assert_enqueued_emails 0 do
          post sign_com_up_emails_url(ri: "jp"),
               params: {
                 customer_email: {
                   raw_address: existing_email.address,
                   confirm_policy: "1",
                 },
                 "cf-turnstile-response": "test",
               },
               headers: default_headers
        end
      end
    end

    assert_response :redirect
    assert_includes response.location, "/sign/up/emails/#{existing_email.public_id}/edit"
    assert_equal I18n.t("sign.app.registration.email.create.verification_code_sent"), flash[:notice]
  end

  test "update for existing email flow redirects to sign in without otp" do
    customer = Customer.create!(status_id: CustomerStatus::ACTIVE, visibility_id: CustomerVisibility::CUSTOMER)
    existing_email = CustomerEmail.create!(
      customer: customer,
      address: "com-existing-skip-otp@example.com",
      confirm_policy: "1",
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
    )

    post sign_com_up_emails_url(ri: "jp"),
         params: {
           customer_email: {
             raw_address: existing_email.address,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    patch sign_com_up_email_url(id: existing_email.public_id, ri: "jp"),
          params: { customer_email: { pass_code: "000000" } },
          headers: default_headers

    assert_redirected_to new_sign_com_in_path(ri: "jp")
    assert_equal I18n.t("sign.app.registration.email.update.sign_in_required"), flash[:notice]
  end

  test "edit missing email resets flow and redirects to new" do
    get edit_sign_com_up_email_url(id: "missing-public-id", ri: "jp"), headers: default_headers

    assert_redirected_to new_sign_com_up_email_path(ri: "jp")
  end

  test "edit with expired session redirects to new" do
    post sign_com_up_emails_url(ri: "jp"),
         params: {
           customer_email: {
             raw_address: "expired-session@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    public_id = response.location.split("/").last(2).first
    email = CustomerEmail.find_by(public_id: public_id)
    email.update!(otp_expires_at: 1.minute.ago)

    get edit_sign_com_up_email_url(id: public_id, ri: "jp"), headers: default_headers

    assert_redirected_to new_sign_com_up_email_path(ri: "jp")
    assert_equal I18n.t("sign.app.registration.email.edit.session_expired"), flash[:notice]
  end

  test "update without code renders edit" do
    post sign_com_up_emails_url(ri: "jp"),
         params: {
           customer_email: {
             raw_address: "missing-code@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    public_id = response.location.split("/").last(2).first

    patch sign_com_up_email_url(id: public_id, ri: "jp"),
          params: { customer_email: { pass_code: "" } },
          headers: default_headers

    assert_response :unprocessable_content
  end

  test "update without a valid session redirects to new" do
    email = CustomerEmail.create!(
      customer: Customer.create!(status_id: CustomerStatus::ACTIVE, visibility_id: CustomerVisibility::CUSTOMER),
      address: "invalid-session@example.com",
      confirm_policy: "1",
      customer_email_status_id: CustomerEmailStatus::UNVERIFIED_WITH_SIGN_UP,
      otp_expires_at: 5.minutes.from_now,
    )

    patch sign_com_up_email_url(id: email.public_id, ri: "jp"),
          params: { customer_email: { pass_code: "123456" } },
          headers: default_headers

    assert_redirected_to new_sign_com_up_email_path(ri: "jp")
  end

  test "create with invalid email fails" do
    post sign_com_up_emails_url(ri: "jp"),
         params: {
           customer_email: {
             raw_address: "invalid-email",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :unprocessable_content
  end

  test "create with unconfirmed policy fails" do
    post sign_com_up_emails_url(ri: "jp"),
         params: {
           customer_email: {
             raw_address: "com-flow-step-2@example.com",
             confirm_policy: "0",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :unprocessable_content
  end

  test "create with turnstile failure returns unprocessable content" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    post sign_com_up_emails_url(ri: "jp"),
         params: {
           customer_email: { raw_address: "turnstile@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :unprocessable_content
  end

  test "create with cooldown active returns too many requests" do
    email_address = "cooldown-up@example.com"

    # First request
    post sign_com_up_emails_url(ri: "jp"),
         params: { customer_email: { raw_address: email_address, confirm_policy: "1" },
                   "cf-turnstile-response": "test", },
         headers: default_headers

    assert_response :redirect

    # Second request immediately should trigger cooldown
    post sign_com_up_emails_url(ri: "jp"),
         params: { customer_email: { raw_address: email_address, confirm_policy: "1" },
                   "cf-turnstile-response": "test", },
         headers: default_headers

    assert_response :too_many_requests
  end

  test "patch update with attempts exceeded redirects to new" do
    post sign_com_up_emails_url(ri: "jp"),
         params: { customer_email: { raw_address: "locked@example.com", confirm_policy: "1" },
                   "cf-turnstile-response": "test", },
         headers: default_headers

    public_id = response.location.split("/").last(2).first
    email = CustomerEmail.find_by(public_id: public_id)

    # Simulate locked state
    email.update!(otp_attempts_count: 10)

    patch sign_com_up_email_url(id: public_id, ri: "jp"),
          params: { customer_email: { pass_code: "123456" } },
          headers: default_headers

    assert_redirected_to new_sign_com_up_email_path(ri: "jp")
    assert_equal I18n.t("sign.app.registration.email.update.attempts_exceeded"), flash[:alert]
  end

  test "direct controller private branches for flow and existing verification" do
    controller = Sign::Com::Up::EmailsController.new
    session_hash = {}
    params_hash = ActionController::Parameters.new(ri: "jp", rd: Base64.urlsafe_encode64("/configuration"))
    redirects = []
    renders = []

    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => host)
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { params_hash }
    controller.define_singleton_method(:flash) { @flash ||= {}.freeze }
    controller.define_singleton_method(:action_name) { @action_name || "new" }
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }
    controller.define_singleton_method(:render) { |*args, **kwargs| renders << [args, kwargs] }
    controller.define_singleton_method(:new_sign_com_up_email_path) { |ri: nil| "/sign/up/emails/new?ri=#{ri}" }
    controller.define_singleton_method(:edit_sign_com_up_email_path) { |email, ri: nil, rd: nil|
      "/sign/up/emails/#{email.public_id}/edit?ri=#{ri}&rd=#{rd}"
    }
    controller.define_singleton_method(:new_sign_com_in_path) { |ri: nil| "/in?ri=#{ri}" }
    controller.define_singleton_method(:t) { |key, **| key }
    controller.define_singleton_method(:safe_internal_path) { |path| path.to_s.start_with?("/") ? path : nil }

    assert_equal "init", controller.send(:email_flow_state)
    session_hash[Sign::Com::Up::EmailsController::SESSION_KEY] = "email_created"
    controller.send(:reset_email_flow!)

    assert_equal "init", session_hash[Sign::Com::Up::EmailsController::SESSION_KEY]

    controller.send(:progress_email_flow!, :create)

    assert_equal "email_created", session_hash[Sign::Com::Up::EmailsController::SESSION_KEY]
    controller.send(:progress_email_flow!, :update)

    assert_equal "email_verified", session_hash[Sign::Com::Up::EmailsController::SESSION_KEY]

    email = CustomerEmail.create!(
      customer: Customer.create!(status_id: CustomerStatus::ACTIVE, visibility_id: CustomerVisibility::CUSTOMER),
      address: "direct-existing@example.com",
      confirm_policy: "1",
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
    )
    controller.instance_variable_set(:@user_email, email)
    session_hash[Sign::Com::Up::EmailsController::EXISTING_EMAIL_SESSION_KEY] = email.id
    session_hash[Sign::Com::Up::EmailsController::EXISTING_EMAIL_SKIP_OTP_SESSION_KEY] = false

    controller.define_singleton_method(:verify_otp_code) { |*, **| { success: false } }
    controller.define_singleton_method(:increment_otp_attempts!) { |record| record.otp_attempts_count = 1 }

    assert_not controller.send(:handle_existing_email_verification, "000000")
    assert_equal "sign.app.registration.email.update.invalid_code", email.errors[:pass_code].last

    email.otp_attempts_count = 10
    controller.define_singleton_method(:increment_otp_attempts!) { |_| nil }

    assert_equal :locked, controller.send(:handle_existing_email_verification, "000000")

    email.otp_attempts_count = 0
    controller.define_singleton_method(:verify_otp_code) { |*, **| { success: true } }
    controller.define_singleton_method(:clear_otp) { |_| @cleared = true }

    assert_equal :redirected, controller.send(:handle_existing_email_verification, "123456")
    assert_equal ["/in?ri=jp", { notice: "sign.app.registration.email.update.sign_in_required" }], redirects.last

    controller.instance_variable_set(:@user_email, CustomerEmail.new)
    controller.send(:render_code_required)

    assert_equal [[:edit], { status: :unprocessable_content }], renders.last

    assert_equal Base64.urlsafe_encode64("/configuration"), controller.send(:sanitized_rd_param)
    params_hash[:rd] = "%%%bad"

    assert_nil controller.send(:sanitized_rd_param)
  end

  private

  def default_headers
    { "Host" => host, "HTTPS" => "on" }
  end

  def host
    ENV["ID_CORPORATE_URL"] || "id.com.localhost"
  end
end

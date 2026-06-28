# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Sign::Up::EmailsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    host! ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")
    cookies["csrf_token"] = csrf_token_value
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    Prosopite.pause do
      [1, 2, 3].each { |id| VisitorStatus.find_or_create_by!(id: id) }
      [0, 1, 2, 3].each { |id| VisitorVisibility.find_or_create_by!(id: id) }
      VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
      VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP)
      VisitorTokenDbscStatus.ensure_defaults!
      VisitorTokenStatus::DEFAULTS.each do |id|
        VisitorTokenStatus.find_or_create_by!(id: id)
      end
    end
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should get new" do
    get new_auth_com_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "[data-controller='turnstile'][data-turnstile-mode-value='render']"
    assert_select "h2", I18n.t("sign.com.registration.email.new.page_title")
    assert_select "input[type=checkbox][name='visitor_email[notifiable]']", count: 1
    assert_select "input[type=checkbox][name='visitor_email[promotional]']", count: 0
    assert_no_match(/UMAXICA \(sign, app\)/, response.body)
  end

  test "edit renders authentication code copy" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: "com-code-copy-#{SecureRandom.hex(4)}@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    get auth_com_sign_up_check_email_otp_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "h1", text: I18n.t("sign.app.authentication.email.edit.page_title")
    assert_select "label", text: I18n.t("sign.app.authentication.email.edit.code_label")
    assert_select "input[placeholder=?]", I18n.t("sign.app.authentication.email.edit.code_placeholder")
    assert_select "input[type=submit][value=?]", I18n.t("sign.app.authentication.email.edit.submit")
    assert_includes response.body, "メールアドレス"
    assert_includes response.body, I18n.t("sign.app.authentication.email.edit.delivery_help")
  end

  test "new rejects when visitor is already logged in" do
    visitor = create_verified_visitor_with_email(email_address: "logged-in-com-up-email@example.com")
    visitor.visitor_telephones.create!(
      number: "+15550002221",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    get new_auth_com_sign_up_email_url(ri: "jp"),
        headers: as_visitor_headers(visitor, host: host)

    assert_redirected_to auth_com_dashboard_url(ri: "jp", host: ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost"))
  end

  test "create rejects when visitor is already logged in" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)

    assert_no_difference("VisitorEmail.count") do
      post auth_com_sign_up_email_url(ri: "jp"),
           params: {
             visitor_email: {
               raw_address: "logged-in-com@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: as_visitor_headers(visitor, host: host)
    end

    assert_response :redirect
  end

  test "collection get is not routed" do
    get auth_com_sign_up_email_url(ri: "jp", hotwire_spark: true, reload: "123"), headers: default_headers

    assert_response :not_found
  end

  test "includes navigation link back to sign in" do
    get new_auth_com_sign_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "a[href=?]", auth_com_sign_up_path(ri: "jp"), count: 1
    assert_select "a[href=?]", auth_com_sign_in_path(ri: "jp"), count: 1
  end

  test "create redirects to edit and allows edit page" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: "com-flow-step@example.com",
             confirm_policy: "1",
             notifiable: "0",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect
    public_id = VisitorEmail.order(:created_at).last.public_id

    assert_not VisitorEmail.find_by!(public_id: public_id).notifiable

    follow_redirect!

    assert_response :success
    assert_equal "/sign/up/check/email/otp", path
  end

  test "create renders unprocessable when visitor_email param missing" do
    assert_no_difference("VisitorEmail.count") do
      post auth_com_sign_up_email_url(ri: "jp"),
           params: { "cf-turnstile-response": "test" },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.com.registration.email.create.address_required")
  end

  test "create renders unprocessable when turnstile fails" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    assert_no_difference("VisitorEmail.count") do
      post auth_com_sign_up_email_url(ri: "jp"),
           params: {
             visitor_email: {
               raw_address: "turnstile-failure@example.com",
               confirm_policy: "1",
             },
             "cf-turnstile-response": "test",
           },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.com.registration.email.create.turnstile_validation_failed")
  end

  test "create with existing email still redirects and does not create a new record" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    existing_email = VisitorEmail.create!(
      visitor: visitor,
      address: "com-existing-signup@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )

    assert_no_difference("Visitor.count") do
      assert_no_difference("VisitorEmail.count") do
        assert_enqueued_emails 0 do
          post auth_com_sign_up_email_url(ri: "jp"),
               params: {
                 visitor_email: {
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
    assert_includes response.location, "/sign/up/check/email/otp"
    assert_equal I18n.t("sign.com.registration.email.create.verification_code_sent"), flash[:notice]
    assert_nil session[:com_sign_up_flow_locator]
  end

  test "edit missing email resets flow and redirects to new" do
    get auth_com_sign_up_check_email_otp_url(ri: "jp"), headers: default_headers

    assert_response :unprocessable_content
    assert_equal "ticket is required", response.body
  end

  test "edit with expired session renders form error without clearing requirements" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: "expired-session@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    public_id = VisitorEmail.order(:created_at).last.public_id
    email = VisitorEmail.find_by(public_id: public_id)
    email.update!(otp_expires_at: 1.minute.ago)
    cycle = VisitorSignUpFlow.find_by!(public_id: session.dig(:com_sign_up_flow_locator, "public_id"))
    completed_requirements = cycle.completed_requirements.deep_dup
    flow_count = VisitorSignUpFlow.count

    get auth_com_sign_up_check_email_otp_url(ri: "jp"), headers: default_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.edit.session_expired")
    assert_equal completed_requirements, cycle.reload.completed_requirements
    assert_equal flow_count, VisitorSignUpFlow.count
  end

  test "create with invalid email fails" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: "invalid-email",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :unprocessable_content
    assert_not_includes response.body, "Visitorを入力してください"
  end

  test "create with unconfirmed policy fails" do
    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
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

    post auth_com_sign_up_email_url(ri: "jp"),
         params: {
           visitor_email: { raw_address: "turnstile@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :unprocessable_content
  end

  test "create inside overwrite window returns too many requests" do
    email_address = "cooldown-up@example.com"

    # First request
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { visitor_email: { raw_address: email_address, confirm_policy: "1" },
                   "cf-turnstile-response": "test", },
         headers: default_headers

    assert_response :redirect

    # Second request immediately should trigger the independent overwrite window
    post auth_com_sign_up_email_url(ri: "jp"),
         params: { visitor_email: { raw_address: email_address, confirm_policy: "1" },
                   "cf-turnstile-response": "test", },
         headers: default_headers

    assert_response :too_many_requests
  end

  test "create after overwrite window replaces unverified email" do
    email_address = "overwrite-window-com@example.com"

    post auth_com_sign_up_email_url(ri: "jp"),
         params: { visitor_email: { raw_address: email_address, confirm_policy: "1" },
                   "cf-turnstile-response": "test", },
         headers: default_headers

    assert_response :redirect
    first_public_id = VisitorEmail.order(:created_at).last.public_id
    first_email = VisitorEmail.find_by!(public_id: first_public_id)
    first_visitor = first_email.visitor

    travel CommonOtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
      post auth_com_sign_up_email_url(ri: "jp"),
           params: { visitor_email: { raw_address: email_address, confirm_policy: "1" },
                     "cf-turnstile-response": "test", },
           headers: default_headers
    end

    assert_response :redirect
    assert_not VisitorEmail.exists?(first_email.id)
    assert_not Visitor.exists?(first_visitor.id)
    new_public_id = VisitorEmail.order(:created_at).last.public_id

    assert VisitorEmail.exists?(public_id: new_public_id)
  end

  def default_headers
    { "Host" => host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end
end

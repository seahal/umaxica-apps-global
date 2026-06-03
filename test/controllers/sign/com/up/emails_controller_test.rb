# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Up::EmailsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
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
    get new_sign_com_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "[data-controller='turnstile'][data-turnstile-mode-value='render']"
    assert_select "h2", I18n.t("sign.com.registration.email.new.page_title")
    assert_select "input[type=checkbox][name='visitor_email[notifiable]']", count: 1
    assert_select "input[type=checkbox][name='visitor_email[promotional]']", count: 0
    assert_no_match(/UMAXICA \(sign, app\)/, response.body)
  end

  test "email sign up finalizes and establishes login from checkpoint" do
    email = "finalize_com_email_#{SecureRandom.hex(4)}@example.com"

    post sign_com_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: email,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    visitor_email = VisitorEmail.order(:created_at).last
    otp_data = visitor_email.get_otp
    pass_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_com_up_email_url(ri: "jp"),
          params: { visitor_email: { pass_code: pass_code } },
          headers: default_headers

    assert_redirected_to sign_com_up_guardrail_url(ri: "jp")

    get sign_com_up_guardrail_url(ri: "jp"), headers: default_headers

    assert_redirected_to sign_com_up_checkpoint_url(ri: "jp")

    get sign_com_up_checkpoint_url(ri: "jp"), headers: default_headers

    assert_response :ok
    assert_select "[data-birthdate-format=iso]"
    assert_select "input[type=number][name=birthdate_year][autocomplete=bday-year]"
    assert_select "input[type=number][name=birthdate_month][autocomplete=bday-month]"
    assert_select "input[type=number][name=birthdate_day][autocomplete=bday-day]"
    assert_select "input[type=hidden][name=requirement][value=birthdate]"

    cycle = VisitorSignUpFlow.order(:id).find_by!(
      principal_id: visitor_email.visitor_id,
      pending_contact_type: "email",
      pending_contact_id: visitor_email.id,
    )

    patch sign_com_up_checkpoint_birthdate_url(ri: "jp"),
          params: {
            requirement: "birthdate",
            birthdate: "2000-01-01",
            checkpoint_version: cycle.checkpoint_version,
          },
          headers: default_headers

    assert_response :redirect

    visitor = visitor_email.reload.visitor

    assert_equal VisitorSignUpFlowStatus::COMPLETED, cycle.reload.status_id
    assert VisitorToken.exists?(visitor_id: visitor.id)
  end

  test "new rejects when visitor is already logged in" do
    visitor = create_verified_visitor_with_email(email_address: "logged-in-com-up-email@example.com")
    visitor.visitor_telephones.create!(
      number: "+15550002221",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    get new_sign_com_up_email_url(ri: "jp"),
        headers: as_visitor_headers(visitor, host: host)

    assert_redirected_to acme_com_dashboard_url(ri: "jp", host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"))
  end

  test "create rejects when visitor is already logged in" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)

    assert_no_difference("VisitorEmail.count") do
      post sign_com_up_email_url(ri: "jp"),
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
    get sign_com_up_email_url(ri: "jp", hotwire_spark: true, reload: "123"), headers: default_headers

    assert_response :not_found
  end

  test "includes navigation link back to sign in" do
    get new_sign_com_up_email_url(ri: "jp"), headers: default_headers

    assert_response :success
    assert_select "a[href=?]", new_sign_com_sign_up_path(ri: "jp"), count: 1
    assert_select "a[href=?]", new_sign_com_sign_in_path(ri: "jp"), count: 1
  end

  test "create redirects to edit and allows edit page" do
    post sign_com_up_email_url(ri: "jp"),
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
    assert_equal "/sign/up/email/edit", path
  end

  test "successful OTP verification routes to guardrail without finalization" do
    post sign_com_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: "client-account-signup@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect
    public_id = VisitorEmail.order(:created_at).last.public_id
    visitor_email = VisitorEmail.find_by!(public_id: public_id)
    otp_data = visitor_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])

    patch sign_com_up_email_url(ri: "jp"),
          params: {
            visitor_email: {
              pass_code: hotp.at(otp_data[:otp_counter]).to_s,
            },
          },
          headers: default_headers

    assert_redirected_to sign_com_up_guardrail_path(ri: "jp")
    visitor = visitor_email.reload.visitor
    cycle = VisitorSignUpFlow.find_by!(public_id: session.dig(:com_sign_up_flow_locator, "public_id"))

    assert_equal VisitorEmailStatus::VERIFIED_WITH_SIGN_UP, visitor_email.visitor_email_status_id
    assert_nil visitor.rp_account
    assert_equal visitor.id, cycle.principal_id
    assert_equal "email", cycle.pending_contact_type
    assert_equal visitor_email.id, cycle.pending_contact_id
    assert_equal "contact_verified", cycle.step
  end

  test "successful OTP verification does not record signup or login audits before finalization" do
    post sign_com_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: "audit-email-signup@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect
    public_id = VisitorEmail.order(:created_at).last.public_id
    visitor_email = VisitorEmail.find_by!(public_id: public_id)
    otp_data = visitor_email.get_otp
    hotp = ROTP::HOTP.new(otp_data[:otp_private_key])

    assert_no_difference("ClientChronicle.count") do
      patch sign_com_up_email_url(ri: "jp"),
            params: {
              visitor_email: {
                pass_code: hotp.at(otp_data[:otp_counter]).to_s,
              },
            },
            headers: default_headers
    end

    visitor = visitor_email.reload.visitor

    assert_equal 0,
                 ClientChronicle.where(
                   event_id: ClientChronicleEvent::SIGNED_UP_WITH_EMAIL,
                   subject_id: visitor.id.to_s,
                   subject_type: "Visitor",
                 ).count
    assert_equal 0,
                 ClientChronicle.where(
                   event_id: ClientChronicleEvent::LOGGED_IN,
                   subject_id: visitor.id.to_s,
                   subject_type: "Visitor",
                 ).count
  end

  test "create renders unprocessable when visitor_email param missing" do
    assert_no_difference("VisitorEmail.count") do
      post sign_com_up_email_url(ri: "jp"),
           params: { "cf-turnstile-response": "test" },
           headers: default_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.com.registration.email.create.address_required")
  end

  test "create renders unprocessable when turnstile fails" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    assert_no_difference("VisitorEmail.count") do
      post sign_com_up_email_url(ri: "jp"),
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
          post sign_com_up_email_url(ri: "jp"),
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
    assert_includes response.location, "/sign/up/email/edit"
    assert_equal I18n.t("sign.com.registration.email.create.verification_code_sent"), flash[:notice]
    assert_nil session[:com_sign_up_flow_locator]
  end

  test "update for existing email flow redirects to sign in without otp" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    existing_email = VisitorEmail.create!(
      visitor: visitor,
      address: "com-existing-skip-otp@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )

    post sign_com_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: existing_email.address,
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    assert_response :redirect

    patch sign_com_up_email_url(ri: "jp"),
          params: { visitor_email: { pass_code: "000000" } },
          headers: default_headers

    assert_redirected_to new_sign_com_sign_in_path(ri: "jp")
    assert_equal I18n.t("sign.app.registration.email.update.sign_in_required"), flash[:notice]
    assert_nil session[:com_sign_up_flow_locator]
  end

  test "edit missing email resets flow and redirects to new" do
    get edit_sign_com_up_email_url(ri: "jp"), headers: default_headers

    assert_redirected_to new_sign_com_up_email_path(ri: "jp")
  end

  test "edit with expired session redirects to new" do
    post sign_com_up_email_url(ri: "jp"),
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

    get edit_sign_com_up_email_url(ri: "jp"), headers: default_headers

    assert_redirected_to new_sign_com_up_email_path(ri: "jp")
    assert_equal I18n.t("sign.app.registration.email.edit.session_expired"), flash[:notice]
  end

  test "update without code renders edit" do
    post sign_com_up_email_url(ri: "jp"),
         params: {
           visitor_email: {
             raw_address: "missing-code@example.com",
             confirm_policy: "1",
           },
           "cf-turnstile-response": "test",
         },
         headers: default_headers

    VisitorEmail.order(:created_at).last.public_id

    patch sign_com_up_email_url(ri: "jp"),
          params: { visitor_email: { pass_code: "" } },
          headers: default_headers

    assert_response :unprocessable_content
  end

  test "update without a valid session redirects to new" do
    VisitorEmail.create!(
      visitor: Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR),
      address: "invalid-session@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP,
      otp_expires_at: 5.minutes.from_now,
    )

    patch sign_com_up_email_url(ri: "jp"),
          params: { visitor_email: { pass_code: "123456" } },
          headers: default_headers

    assert_redirected_to new_sign_com_up_email_path(ri: "jp")
  end

  test "create with invalid email fails" do
    post sign_com_up_email_url(ri: "jp"),
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
    post sign_com_up_email_url(ri: "jp"),
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

    post sign_com_up_email_url(ri: "jp"),
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
    post sign_com_up_email_url(ri: "jp"),
         params: { visitor_email: { raw_address: email_address, confirm_policy: "1" },
                   "cf-turnstile-response": "test", },
         headers: default_headers

    assert_response :redirect

    # Second request immediately should trigger the independent overwrite window
    post sign_com_up_email_url(ri: "jp"),
         params: { visitor_email: { raw_address: email_address, confirm_policy: "1" },
                   "cf-turnstile-response": "test", },
         headers: default_headers

    assert_response :too_many_requests
  end

  test "create after overwrite window replaces unverified email" do
    email_address = "overwrite-window-com@example.com"

    post sign_com_up_email_url(ri: "jp"),
         params: { visitor_email: { raw_address: email_address, confirm_policy: "1" },
                   "cf-turnstile-response": "test", },
         headers: default_headers

    assert_response :redirect
    first_public_id = VisitorEmail.order(:created_at).last.public_id
    first_email = VisitorEmail.find_by!(public_id: first_public_id)
    first_visitor = first_email.visitor

    travel Common::OtpPolicy::REREGISTRATION_OVERWRITE_WINDOW + 1.second do
      post sign_com_up_email_url(ri: "jp"),
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

  test "patch update with attempts exceeded redirects to new" do
    post sign_com_up_email_url(ri: "jp"),
         params: { visitor_email: { raw_address: "locked@example.com", confirm_policy: "1" },
                   "cf-turnstile-response": "test", },
         headers: default_headers

    public_id = VisitorEmail.order(:created_at).last.public_id
    email = VisitorEmail.find_by(public_id: public_id)

    # Simulate locked state
    email.update!(otp_attempts_count: 10)

    patch sign_com_up_email_url(ri: "jp"),
          params: { visitor_email: { pass_code: "123456" } },
          headers: default_headers

    assert_redirected_to new_sign_com_up_email_path(ri: "jp")
    assert_equal I18n.t("sign.app.registration.email.update.attempts_exceeded"), flash[:alert]
  end

  test "direct controller private branches for flow and existing verification" do
    controller = Sign::Com::Up::EmailsController.new
    session_hash = {}
    params_hash = ActionController::Parameters.new(ri: "jp", pt: "/settings")
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
    controller.define_singleton_method(:new_sign_com_up_email_path) { |ri: nil| "/sign/up/email/new?ri=#{ri}" }
    controller.define_singleton_method(:edit_sign_com_up_email_path) { |_email, ri: nil, pt: nil|
      "/sign/up/email/edit?ri=#{ri}&pt=#{pt}"
    }
    controller.define_singleton_method(:new_sign_com_sign_in_path) { |ri: nil| "/in?ri=#{ri}" }
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

    email = VisitorEmail.create!(
      visitor: Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR),
      address: "direct-existing@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    controller.instance_variable_set(:@user_email, email)
    session_hash[Sign::Com::Up::EmailsController::EXISTING_EMAIL_SESSION_KEY] = email.id
    session_hash[Sign::Com::Up::EmailsController::EXISTING_EMAIL_SKIP_OTP_SESSION_KEY] = false

    controller.define_singleton_method(:verify_otp_code) { |*, **| { success: false } }
    controller.define_singleton_method(:increment_otp_attempts!) { |record| record.otp_attempts_count = 1 }

    assert_not controller.send(:handle_existing_email_verification, "000000")
    assert_equal "sign.app.registration.email.update.invalid_code", email.errors[:pass_code].last

    email.otp_attempts_count = 10
    email.otp_last_sent_at = Time.current
    controller.define_singleton_method(:increment_otp_attempts!) { |_| nil }

    assert_equal :locked, controller.send(:handle_existing_email_verification, "000000")

    email.otp_attempts_count = 0
    controller.define_singleton_method(:verify_otp_code) { |*, **| { success: true } }
    controller.define_singleton_method(:clear_otp) { |_| @cleared = true }

    assert_equal :redirected, controller.send(:handle_existing_email_verification, "123456")
    assert_equal ["/in?ri=jp", { notice: "sign.app.registration.email.update.sign_in_required" }], redirects.last

    controller.instance_variable_set(:@user_email, VisitorEmail.new)
    controller.send(:render_code_required)

    assert_equal [[:edit], { status: :unprocessable_content }], renders.last

    assert_match(/--/, controller.send(:sanitized_rt_param))
    params_hash[:pt] = "%%%bad"

    assert_nil controller.send(:sanitized_rt_param)
  end

  private

  def default_headers
    { "Host" => host, "HTTPS" => "on", "X-CSRF-Token" => csrf_token_value }
  end

  def host
    ENV["ID_CORPORATE_URL"] || "id.com.localhost"
  end
end

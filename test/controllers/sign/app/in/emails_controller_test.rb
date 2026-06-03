# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::In::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :client_statuses, :operator_statuses, :client_email_statuses

  include ActiveSupport::Testing::TimeHelpers

  test "should get new" do
    get new_sign_app_in_email_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success

    assert_select "h1", I18n.t("sign.app.authentication.email.new.page_title")

    assert_select "a"

    assert_nil cookies[:htop_private_key]
    #    assert_select "a[href=?]",
    #                  new_sign_app_authentication_path(query, ri: "jp"),
    #                  I18n.t("sign.app.authentication.new.back")
    assert_response :success
  end

  test "reject already logged in user" do
    user = clients(:one)
    get new_sign_app_in_email_url(ri: "jp"),
        headers: as_user_headers(user, host: @host)

    assert_response :bad_request
    assert_includes response.body, I18n.t("sign.app.authentication.email.new.you_have_already_logged_in")
  end

  test "reject already logged in staff" do
    staff = operators(:one)
    get new_sign_app_in_email_url(ri: "jp"),
        headers: { "Host" => @host, "X-TEST-CURRENT-STAFF" => staff.id }

    assert_response :success
    # assert_equal I18n.t("sign.app.authentication.email.new.you_have_already_logged_in"), response.body
  end
  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV["ID_SERVICE_URL"] || "id.app.localhost"
    ActionMailer::Base.deliveries.clear
    CloudflareTurnstile.test_mode = true
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "GET new displays email form" do
    get new_sign_app_in_email_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
    assert_select "input[name='client_email[address]']"
  end

  test "POST create without valid email redirects (enumeration protection)" do
    post sign_app_in_email_url(ri: "jp"),
         params: { user_email: { address: "nonexistent@example.com" } },
         headers: { "Host" => @host }

    # Should redirect to edit to prevent enumeration
    assert_response :found
    assert_redirected_to %r{/sign/in/email/edit}
    assert_nil Sign::App::In::EmailAuthenticationState.load(session)&.id
  end

  test "POST create responds the same for existing and missing emails" do
    user = clients(:one)
    existing_email = user.client_emails.create!(address: "enum_test@example.com")

    existing_session = open_session
    existing_session.post(
      sign_app_in_email_url(ri: "jp"),
      params: { user_email: { address: existing_email.address } },
      headers: { "Host" => @host },
    )

    missing_session = open_session
    missing_session.post(
      sign_app_in_email_url(ri: "jp"),
      params: { user_email: { address: "missing-enum@example.com" } },
      headers: { "Host" => @host },
    )

    assert_equal existing_session.response.status, missing_session.response.status
    assert_equal existing_session.response.location, missing_session.response.location

    if existing_session.flash[:notice].nil?
      assert_nil missing_session.flash[:notice]
    else
      assert_equal existing_session.flash[:notice], missing_session.flash[:notice]
    end
  end

  test "POST create with existing email generates OTP and redirects to edit" do
    # Create a test email in the database
    user = clients(:one)
    test_email = "auth_test_#{SecureRandom.hex(4)}@example.com"
    user.client_emails.create!(address: test_email)

    # Make the POST request with valid email and Turnstile response
    # Turnstile is automatically mocked to return true in test environment
    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to %r{/sign/in/email/edit}

    follow_redirect!
    follow_redirect! if response.redirect?

    assert_response :success
    assert_select "input[type=submit][value=?]", I18n.t("sign.app.authentication.email.edit.submit")
  end

  test "timing attack protection in update action" do
    # Create and verify an email
    user = clients(:one)
    test_email = user.client_emails.create!(address: "timing_test@example.com")
    test_email.update!(pass_code: "123456", otp_attempts_count: 0)

    # Start session
    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    follow_redirect!
    session_id = cookies["user_email_authentication_id"]

    # Measure time for valid code
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    patch sign_app_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: "123456" } },
          headers: { "Host" => @host, "Cookie" => "user_email_authentication_id=#{session_id}" }
    valid_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    # Reset for invalid code test
    test_email.update!(pass_code: "123456", otp_attempts_count: 0)
    travel Common::OtpPolicy::SEND_COOLDOWN + 1.second do
      post sign_app_in_email_url(ri: "jp"),
           params: {
             :user_email => { address: test_email.address },
             "cf-turnstile-response" => "test_token",
           },
           headers: { "Host" => @host }
    end

    follow_redirect!
    session_id = cookies["user_email_authentication_id"]

    # Measure time for invalid code
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    patch sign_app_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: "999999" } },
          headers: { "Host" => @host, "Cookie" => "user_email_authentication_id=#{session_id}" }
    invalid_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    # Times should be similar (within 50% tolerance for timing attack protection)
    time_difference = (valid_time - invalid_time).abs
    max_allowed_difference = [valid_time, invalid_time].max * 1

    assert_operator time_difference, :<=, max_allowed_difference,
                    "Response times differ too much: valid=#{valid_time.round(4)}s, invalid=#{invalid_time.round(4)}s"
  end

  # Turnstile Widget Verification Tests
  test "new authentication email page renders Turnstile widget" do
    get new_sign_app_in_email_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
    assert_select "div[id^='cf-turnstile-']", count: 1
  end

  # Login Tests

  test "successful OTP verification redirects to dashboard" do
    # Create email with user association
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "login_test_#{SecureRandom.hex(4)}@example.com",
    )

    # Start authentication process to trigger email discovery
    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_equal test_email.id, Sign::App::In::EmailAuthenticationState.load(session)&.id

    # Generate valid OTP code
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s

    # Store OTP on the email manually (bypasses application logic)
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    # Verify OTP to log in
    patch sign_app_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to sign_app_in_checkpoint_path(ri: "jp")

    cycle = ClientSignInFlow.where(principal_id: user.id).recent_first.first

    assert_equal "CHECKPOINT_PENDING", cycle.state
    assert_equal cycle.public_id, session.dig(:app_sign_in_flow_locator, "public_id")
  end

  test "successful OTP verification sets auth cookies with app domain" do
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "cookie_domain_in_#{SecureRandom.hex(4)}@example.com",
    )

    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 67_890
    valid_pass_code = ROTP::HOTP.new(otp_private_key).at(otp_counter).to_s
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    patch sign_app_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host }

    set_cookie = response.headers["Set-Cookie"].to_s

    assert_match(/domain=\.umaxica\.app/i, set_cookie)
    assert_no_match(/domain=\.localhost/i, set_cookie)
  end

  test "email sign-in redirects to MFA challenge when MFA is enabled" do
    user = clients(:one)
    user.update!(mfa_level_enabled: true)
    test_email = user.client_emails.create!(
      address: "mfa_email_login_#{SecureRandom.hex(4)}@example.com",
    )

    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 55_555
    valid_pass_code = ROTP::HOTP.new(otp_private_key).at(otp_counter).to_s
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    patch sign_app_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to sign_app_in_challenge_path(ri: "jp")
  end

  def test_setup_cooldown_test_email
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "cooldown_test_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      perform_enqueued_jobs do
        post(
          sign_app_in_email_url(ri: "jp"),
          params: {
            :user_email => { address: test_email.address },
            "cf-turnstile-response" => "test_token",
          },
          headers: { "Host" => @host },
        )
      end
    end

    assert_response :found
    test_email.reload
    test_email
  end

  test "otp initial request sends email" do
    test_email = test_setup_cooldown_test_email

    assert_not_nil test_email.otp_last_sent_at
  end

  test "otp immediate resend is rejected with cooldown" do
    test_email = test_setup_cooldown_test_email
    initial_sent_at = test_email.otp_last_sent_at

    assert_no_difference -> { ActionMailer::Base.deliveries.count } do
      post sign_app_in_email_url(ri: "jp"),
           params: {
             :user_email => { address: test_email.address },
             "cf-turnstile-response" => "test_token",
           },
           headers: { "Host" => @host }
    end

    assert_response :too_many_requests
    assert_includes @response.body, I18n.t("sign.app.authentication.email.create.cooldown")
    assert_equal initial_sent_at, test_email.reload.otp_last_sent_at
  end

  test "otp resend still rejected after 29 seconds" do
    test_email = test_setup_cooldown_test_email

    travel 29.seconds do
      assert_no_difference -> { ActionMailer::Base.deliveries.count } do
        post sign_app_in_email_url(ri: "jp"),
             params: {
               :user_email => { address: test_email.address },
               "cf-turnstile-response" => "test_token",
             },
             headers: { "Host" => @host }
      end

      assert_response :too_many_requests
    end
  end

  test "otp resend succeeds after cooldown expires" do
    test_email = test_setup_cooldown_test_email
    initial_sent_at = test_email.otp_last_sent_at

    travel 31.seconds do
      assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
        perform_enqueued_jobs do
          post sign_app_in_email_url(ri: "jp"),
               params: {
                 :user_email => { address: test_email.address },
                 "cf-turnstile-response" => "test_token",
               },
               headers: { "Host" => @host }
        end
      end

      assert_response :found
      assert_operator test_email.reload.otp_last_sent_at, :>, initial_sent_at
    end
  end

  test "email sign in locks after five invalid OTP attempts" do
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "lockout_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    Email::MAX_OTP_ATTEMPTS.times do
      patch sign_app_in_email_url(ri: "jp"),
            params: { user_email: { pass_code: "000000" } },
            headers: { "Host" => @host }
    end

    test_email.reload

    assert_response :unprocessable_content
    assert_predicate test_email, :locked?
    assert_operator test_email.lockout_expires_at, :>, Time.current
  end

  test "email sign in create does not send OTP during lockout" do
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "create_locked_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      locked_at: 5.minutes.from_now,
      otp_attempts_count: Email::MAX_OTP_ATTEMPTS,
    )

    travel Common::OtpPolicy::SEND_COOLDOWN + 1.second do
      assert_no_difference -> { ActionMailer::Base.deliveries.count } do
        post sign_app_in_email_url(ri: "jp"),
             params: {
               :user_email => { address: test_email.address },
               "cf-turnstile-response" => "test_token",
             },
             headers: { "Host" => @host }
      end
    end

    assert_response :found
    assert_redirected_to %r{/sign/in/email/edit}
  end

  test "successful OTP verification records login audit event" do
    user = clients(:one)
    test_email = user.client_emails.create!(address: "audit_login_#{SecureRandom.hex(4)}@example.com")

    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_equal test_email.id, Sign::App::In::EmailAuthenticationState.load(session)&.id

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    assert_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::LOGGED_IN).count }, 1 do
      patch sign_app_in_email_url(ri: "jp"),
            params: { user_email: { pass_code: valid_pass_code } },
            headers: { "Host" => @host }
    end

    audit = ClientChronicle.order(created_at: :desc).first

    assert_equal ClientChronicleEvent::LOGGED_IN, audit.event_id
    assert_equal user, audit.user
  end

  test "invalid OTP code returns error message" do
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "invalid_otp_test_#{SecureRandom.hex(4)}@example.com",
    )

    # Start authentication
    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_equal test_email.id, Sign::App::In::EmailAuthenticationState.load(session)&.id

    # Set up valid OTP but provide wrong code
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    # Try with invalid code
    patch sign_app_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: "999999" } },
          headers: { "Host" => @host }

    # Should render edit page with error
    assert_response :unprocessable_content
    assert_includes @response.body, I18n.t("sign.app.authentication.email.update.invalid_code", locale: :ja)
  end

  test "invalid OTP attempt records login failed audit event" do
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "audit_login_failed_#{SecureRandom.hex(4)}@example.com",
    )

    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_equal test_email.id, Sign::App::In::EmailAuthenticationState.load(session)&.id

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 56_789
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    assert_difference -> { ClientChronicle.where(event_id: ClientChronicleEvent::LOGIN_FAILED).count }, 1 do
      patch sign_app_in_email_url(ri: "jp"),
            params: { user_email: { pass_code: "000000" } },
            headers: { "Host" => @host }
    end

    audit = ClientChronicle.order(created_at: :desc).first

    assert_equal ClientChronicleEvent::LOGIN_FAILED, audit.event_id
    assert_equal user, audit.user
  end

  test "already logged in user cannot authenticate via post" do
    user = clients(:one)
    post sign_app_in_email_url(ri: "jp"),
         params: { user_email: { address: "some@example.com" } },
         headers: { "Host" => @host, "X-TEST-CURRENT-USER" => user.id }

    assert_response :bad_request
  end

  test "redirects to encoded URL after successful login when pt parameter is provided" do
    # Create a test user and email
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "redirect_login_test_#{SecureRandom.hex(4)}@example.com",
    )

    redirect_url = sign_app_settings_path(ri: "jp")
    pt = redirect_url

    # Start authentication with pt parameter
    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
           :pt => pt,
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_not_includes response.location, "pt="
    assert_equal test_email.id, Sign::App::In::EmailAuthenticationState.load(session)&.id
    assert_nil session[:user_email_authentication_rt]

    # Generate valid OTP code
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s

    # Store OTP
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    # Verify OTP with pt parameter
    patch sign_app_in_email_url(ri: "jp"),
          params: {
            user_email: { pass_code: valid_pass_code },
            pt: pt,
          },
          headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to sign_app_in_checkpoint_path(ri: "jp")

    cycle = ClientSignInFlow.where(principal_id: user.id).recent_first.first

    assert_equal "CHECKPOINT_PENDING", cycle.state
    assert_nil cycle.return_to

    follow_redirect!

    assert_response :redirect
    assert_redirected_to acme_app_welcome_entry_url(ri: "jp", host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"))
    assert_equal "DASHBOARD_PENDING", cycle.reload.state
    assert_nil cycle.return_to
  end

  test "rejects external pt parameter after successful login" do
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "redirect_external_test_#{SecureRandom.hex(4)}@example.com",
    )

    pt = "https://example.com/evil"

    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
           :pt => pt,
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_no_match(/pt=/, response.location)

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s

    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    patch sign_app_in_email_url(ri: "jp"),
          params: {
            user_email: { pass_code: valid_pass_code },
            pt: pt,
          },
          headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to sign_app_in_checkpoint_path(ri: "jp")
  end

  test "resets session ID after successful email login" do
    # Create email with user association
    user = clients(:one)
    test_email = user.client_emails.create!(
      address: "session_reset_login_#{SecureRandom.hex(4)}@example.com",
    )

    # Start authentication
    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found
    assert_predicate Sign::App::In::EmailAuthenticationState.load(session)&.id, :present?

    # Generate valid OTP code
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s

    # Store OTP
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    # Ensure we have a session
    old_session_id = session.id

    # Verify OTP to log in
    patch sign_app_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host }

    assert_response :found
    assert_not_nil session.id
    assert_not_equal old_session_id, session.id
  end

  test "email login with session limit exceeded redirects to session management" do
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all

    # Create 2 active sessions to hit the limit
    2.times do
      create_rotated_active_user_session(user, rotations: 3)
    end

    test_email = user.client_emails.create!(
      address: "session_limit_email_#{SecureRandom.hex(4)}@example.com",
    )

    # Start authentication
    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    # Generate valid OTP code
    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    # Verify OTP - should redirect to session management, not "/"
    patch sign_app_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host }

    assert_response :found
    assert_redirected_to sign_app_in_session_path(ri: "jp")
    assert_equal I18n.t("sign.app.in.session.restricted_notice"), flash[:notice]

    # The current session-limit gate keeps the pending login in session state.
    restricted = ClientToken.where(user_id: user.id, user_token_status_id: ClientTokenStatus::RESTRICTED)

    assert_equal 0, restricted.count

    # Session limit gate should be issued
    assert_predicate session[SessionLimitGate::GATE_SESSION_KEY], :present?
  end

  test "email login (JSON) with session limit exceeded returns session_restricted" do
    user = clients(:one)
    ClientToken.where(user_id: user.id).delete_all

    2.times do
      create_rotated_active_user_session(user, rotations: 3)
    end

    test_email = user.client_emails.create!(
      address: "session_limit_json_#{SecureRandom.hex(4)}@example.com",
    )

    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: test_email.address },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 12_345
    hotp = ROTP::HOTP.new(otp_private_key)
    valid_pass_code = hotp.at(otp_counter).to_s
    test_email.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    patch sign_app_in_email_url(ri: "jp"),
          params: { user_email: { pass_code: valid_pass_code } },
          headers: { "Host" => @host, "Accept" => "application/json" },
          as: :json

    assert_response :ok
    json = response.parsed_body

    assert_equal "session_restricted", json["status"]
    assert_equal sign_app_in_session_path(ri: "jp"), json["redirect_url"]
  end

  test "cooldown applies identically for non-existing emails (anti-enumeration)" do
    non_existing = "does_not_exist_#{SecureRandom.hex(4)}@example.com"

    # First attempt -- redirect (same as existing email)
    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: non_existing },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found

    # Second attempt immediately -- 429 (same as existing email)
    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: non_existing },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :too_many_requests
    assert_includes @response.body, I18n.t("sign.app.authentication.email.create.cooldown")

    # After cooldown -- allowed again
    travel Common::OtpPolicy::SEND_COOLDOWN + 1.second do
      post sign_app_in_email_url(ri: "jp"),
           params: {
             :user_email => { address: non_existing },
             "cf-turnstile-response" => "test_token",
           },
           headers: { "Host" => @host }

      assert_response :found
    end
  end

  test "cooldown does not block different email addresses" do
    first_email = "first_signin_#{SecureRandom.hex(4)}@example.com"
    second_email = "second_signin_#{SecureRandom.hex(4)}@example.com"

    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: first_email },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found

    # Different email should not be blocked
    post sign_app_in_email_url(ri: "jp"),
         params: {
           :user_email => { address: second_email },
           "cf-turnstile-response" => "test_token",
         },
         headers: { "Host" => @host }

    assert_response :found
  end

  test "sign-in cooldown i18n keys exist in both locales" do
    assert_not_nil I18n.t("sign.app.authentication.email.create.cooldown", locale: :ja, default: nil)
    assert_not_nil I18n.t("sign.app.authentication.email.create.cooldown", locale: :en, default: nil)
  end

  private

  def create_rotated_active_user_session(user, rotations:)
    token = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = Sign::RefreshTokenService.call(refresh_token: refresh)[:refresh_token]
    end
  end
end

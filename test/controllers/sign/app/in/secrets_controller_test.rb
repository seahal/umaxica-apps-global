# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::In::SecretsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_secret_kinds, :client_secret_statuses, :client_email_statuses,
           :client_telephone_statuses

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    @raw_email = "secret_login_#{SecureRandom.hex(4)}@example.com".freeze
    @email = @user.client_emails.create!(address: @raw_email, user_email_status_id: ClientEmailStatus::VERIFIED)
    @telephone = @user.client_telephones.create!(number: "+819012345678")
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should get new" do
    get new_sign_app_in_secret_url(ri: "jp"), headers: default_headers

    assert_response :success
  end

  test "should return unprocessable_content with invalid params" do
    post sign_app_in_secret_url(ri: "jp"),
         params: { secret_login_form: { identifier: "", secret_value: "" } },
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")
  end

  test "identifier without @ or + is rejected" do
    _secret, raw_secret = issue_secret!

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: "plaintext", secret_value: raw_secret),
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")
  end

  test "returns 403 when user is at session hard_reject limit" do
    _secret, raw_secret = issue_secret!(kind: ClientSecretKind::PERMANENT, uses: 10)

    # Create 2 active + 1 restricted to hit the hard limit
    ClientToken.where(user_id: @user.id).delete_all
    Prosopite.pause do
      2.times do
        create_rotated_active_user_session(@user, rotations: 3)
      end
    end
    restricted = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted.rotate_refresh_token!(discarded_at: 15.minutes.from_now)

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: raw_secret),
         headers: default_headers

    assert_response :forbidden
    assert_includes response.body, I18n.t("session_limit.login_limit_exceeded")
  end

  test "redirects to session management when logical session limit is reached despite rotated rows" do
    _secret, raw_secret = issue_secret!(kind: ClientSecretKind::PERMANENT, uses: 10)

    ClientToken.where(user_id: @user.id).delete_all
    Prosopite.pause do
      2.times do
        create_rotated_active_user_session(@user, rotations: 4)
      end
    end

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: raw_secret),
         headers: default_headers

    assert_response :found
    assert_redirected_to sign_app_in_session_path(ri: "jp")
    assert_equal I18n.t("sign.app.in.session.restricted_notice"), flash[:notice]
    assert_equal 0, ClientToken.where(user_id: @user.id, user_token_status_id: ClientTokenStatus::RESTRICTED).count
  end

  test "turnstile failure returns unified authentication error" do
    CloudflareTurnstile.test_validation_response = { "success" => false }
    _secret, raw_secret = issue_secret!

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: raw_secret),
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")
  end

  test "email and matching permanent secret logs in successfully" do
    _secret, raw_secret = issue_secret!(kind: ClientSecretKind::PERMANENT, uses: 10)

    get new_sign_app_in_secret_url(ri: "jp"), headers: default_headers

    assert_response :success
    old_session_id = session.id

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email.upcase, secret_value: raw_secret),
         headers: default_headers

    assert_response :found
    assert_redirected_to sign_app_in_checkpoint_path(ri: "jp")
    assert_not_equal old_session_id, session.id
  end

  test "telephone and matching permanent secret logs in successfully" do
    _secret, raw_secret = issue_secret!(kind: ClientSecretKind::PERMANENT, uses: 10)

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: "+819012345678", secret_value: raw_secret),
         headers: default_headers

    assert_response :found
    assert_redirected_to sign_app_in_checkpoint_path(ri: "jp")
  end

  test "secret sign-in redirects to MFA challenge for weak method when MFA is enabled" do
    @user.update!(multi_factor_enabled: true)
    _secret, raw_secret = issue_secret!(kind: ClientSecretKind::PERMANENT, uses: 10)

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: raw_secret),
         headers: default_headers

    assert_response :found
    assert_redirected_to sign_app_in_challenge_path(ri: "jp")
  end

  test "mismatched secret fails with unified message" do
    _secret, _raw_secret = issue_secret!

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: "wrong-secret"),
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")
  end

  test "unknown user fails with unified message" do
    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: "missing-#{SecureRandom.hex(4)}@example.com", secret_value: "nope"),
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")
  end

  test "known user with no secret fails with unified message" do
    @user.client_secrets.delete_all

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: "nope"),
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")
  end

  test "reserved user cannot sign in with secret" do
    reserved_user = clients(:reserved_user)
    email = reserved_user.client_emails.create!(
      address: "reserved_secret_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    secret, raw_secret = ClientSecret.issue!(
      name: "Reserved secret",
      user_id: reserved_user.id,
      user_secret_kind_id: ClientSecretKind::PERMANENT,
      uses: 10,
      status: :active,
    )

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: email.address, secret_value: raw_secret),
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")
    assert_equal ClientSecretStatus::ACTIVE, secret.reload.user_secret_status_id
  end

  test "secret login returns same response for secret mismatch and missing verified pii" do
    _secret, _raw_secret = issue_secret!(kind: ClientSecretKind::PERMANENT, uses: 10)

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: "wrong-secret"),
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")

    user_without_verified_pii = Client.create!(status_id: ClientStatus::NOTHING)
    email_for_secret_issue = user_without_verified_pii.client_emails.create!(
      address: "secret_verified_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    _pii_secret, pii_raw_secret = ClientSecret.issue!(
      name: "PII missing secret",
      user_id: user_without_verified_pii.id,
      user_secret_kind_id: ClientSecretKind::PERMANENT,
      uses: 10,
      status: :active,
    )
    email_for_secret_issue.update!(user_email_status_id: ClientEmailStatus::UNVERIFIED)
    unverified_email = user_without_verified_pii.client_emails.create!(
      address: "secret_unverified_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: unverified_email.address, secret_value: pii_raw_secret),
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")
  end

  test "one-time secret decrements uses and cannot be reused once exhausted" do
    one_time_secret, raw_secret = issue_secret!(kind: ClientSecretKind::ONE_TIME, uses: 1)

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: raw_secret),
         headers: default_headers

    assert_response :found
    assert_redirected_to sign_app_in_checkpoint_path(ri: "jp")
    assert_equal 0, one_time_secret.reload.uses_remaining
    assert_equal ClientSecretStatus::USED, one_time_secret.user_secret_status_id

    reset!
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: raw_secret),
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")
  end

  test "expired secret fails authentication" do
    _secret, raw_secret = issue_secret!(discarded_at: 1.minute.ago)

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: raw_secret),
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")
  end

  test "one-time secret with uses_remaining 0 fails authentication" do
    secret, raw_secret = issue_secret!(kind: ClientSecretKind::ONE_TIME, uses: 1)
    secret.update!(uses_remaining: 0)

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: raw_secret),
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")
  end

  test "secret with disallowed status fails authentication" do
    _secret, raw_secret = issue_secret!(status: :revoked)

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: raw_secret),
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")
  end

  test "secret with disallowed kind fails authentication" do
    _secret, raw_secret = issue_secret!(kind: ClientSecretKind::TOTP, uses: 10)

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: raw_secret),
         headers: default_headers

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("sign.app.authentication.secret.create.invalid")
  end

  test "secret login succeeds without extra confirmation parameter" do
    _secret, raw_secret = issue_secret!

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: raw_secret),
         headers: default_headers

    assert_response :found
    assert_redirected_to sign_app_in_checkpoint_path(ri: "jp")
    assert_not_nil session.id
  end

  test "guest request does not query clients with null mfa_user_id" do
    queries =
      capture_sql_queries do
        get(new_sign_app_in_secret_url(ri: "jp"), headers: default_headers)

        assert_response :success
      end

    assert_response :success
    assert_not queries.any? { |sql| sql.match?(/FROM "clients".*"clients"."id" IS NULL/i) },
               "expected no clients.id IS NULL query, got: #{queries.grep(/clients/i).join("\n")}"
  end

  private

  def create_rotated_active_user_session(user, rotations:)
    token = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = Sign::RefreshTokenService.call(refresh_token: refresh)[:refresh_token]
    end
  end

  def issue_secret!(kind: ClientSecretKind::PERMANENT, uses: 1, discarded_at: nil, status: :active)
    ClientSecret.issue!(
      name: "Secret-#{SecureRandom.hex(4)}",
      user_id: @user.id,
      user_secret_kind_id: kind,
      uses: uses,
      discarded_at: discarded_at,
      status: status,
    )
  end

  def login_params(identifier:, secret_value:)
    {
      secret_login_form: {
        identifier: identifier,
        secret_value: secret_value,
      },
      "cf-turnstile-response": "test_token",
    }
  end

  def default_headers
    { "Host" => ENV["ID_SERVICE_URL"] || "id.app.localhost" }
  end

  def capture_sql_queries
    queries = []
    callback =
      lambda do |_name, _started, _finished, _id, payload|
        sql = payload[:sql].to_s
        next if sql.blank?
        next if payload[:name].to_s == "SCHEMA"
        next if payload[:cached]

        queries << sql
      end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end
    queries
  end

  public

  test "secret login with session limit exceeded redirects to session management" do
    ClientToken.where(user_id: @user.id).delete_all

    # Create 2 active sessions to hit the limit
    Prosopite.pause do
      2.times do
        token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
        token.rotate_refresh_token!
      end
    end

    _secret, raw_secret = issue_secret!(kind: ClientSecretKind::PERMANENT, uses: 10)

    post sign_app_in_secret_url(ri: "jp"),
         params: login_params(identifier: @raw_email, secret_value: raw_secret),
         headers: default_headers

    assert_response :found
    assert_redirected_to sign_app_in_session_path(ri: "jp")
    assert_equal 0, ClientToken.where(user_id: @user.id, user_token_status_id: ClientTokenStatus::RESTRICTED).count
  end

  test "direct controller branches for mfa and standard secret flows" do
    controller = Sign::App::In::SecretsController.new
    session_hash = {}
    params_hash = ActionController::Parameters.new(
      "ri" => "jp",
      "cf-turnstile-response" => "test_token",
    )
    failures = []
    redirects = []
    target_user = @user

    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => host)
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { params_hash }
    controller.define_singleton_method(:render_failed_login) { |**kwargs| failures << kwargs }
    controller.define_singleton_method(:render_session_limit_hard_reject) { |**kwargs|
      failures << kwargs.merge(reason: :hard_reject)
    }
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }
    controller.define_singleton_method(:redirect_to_pt_or_default!) { |pt, default_path:|
      redirects << [pt || default_path, {}]
    }
    controller.define_singleton_method(:sign_app_configuration_path) { |ri: nil| "/configuration?ri=#{ri}" }
    controller.define_singleton_method(:sign_app_dashboard_path) { |ri: nil, pt: nil|
      "/dashboard?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:sign_app_in_session_path) { "/sign/in/session" }
    controller.define_singleton_method(:sign_app_in_checkpoint_path) { |pt: nil, ri: nil|
      "/sign/in/checkpoint?pt=#{pt}&ri=#{ri}"
    }
    controller.define_singleton_method(:t) { |key| key }

    controller.new

    assert_instance_of Sign::App::In::SecretsController::SecretLoginForm,
                       controller.instance_variable_get(:@secret_form)

    session_hash[Sign::App::In::SecretsController::MFA_USER_SESSION_KEY] = @user.id
    controller.remove_instance_variable(:@mfa_user)
    controller.define_singleton_method(:active_secret_hints_for) { |_| ["hint"] }
    controller.new

    assert_instance_of Sign::App::In::SecretsController::MfaSecretForm, controller.instance_variable_get(:@secret_form)
    assert_equal ["hint"], controller.instance_variable_get(:@secret_hints)

    params_hash[:mfa_secret_form] = ActionController::Parameters.new(secret_value: "")
    controller.handle_mfa_login

    assert_equal :form_invalid, failures.last[:reason]

    params_hash[:mfa_secret_form] = ActionController::Parameters.new(secret_value: "secret")
    controller.define_singleton_method(:cloudflare_turnstile_validation) { { "success" => false } }
    controller.handle_mfa_login

    assert_equal :turnstile_failed, failures.last[:reason]

    secret = Struct.new(:id).new(99)
    controller.define_singleton_method(:cloudflare_turnstile_validation) { { "success" => true } }
    controller.define_singleton_method(:verify_secret_for_sign_in) do |user:, raw_secret:|
      Sign::App::In::SecretsController::SecretVerificationResult.new(
        secret: secret, reason: :success,
        details: { user_id: user.id, raw: raw_secret },
      )
    end
    controller.define_singleton_method(:handle_successful_mfa) { |u, verified_secret|
      redirects << [u.id, secret_id: verified_secret.id]
    }
    controller.handle_mfa_login

    assert_equal [@user.id, { secret_id: 99 }], redirects.last

    session_hash.delete(Sign::App::In::SecretsController::MFA_USER_SESSION_KEY)
    params_hash.delete(:mfa_secret_form)
    params_hash[:secret_login_form] = ActionController::Parameters.new(identifier: "", secret_value: "")
    controller.handle_standard_login

    assert_equal :form_invalid, failures.last[:reason]

    params_hash[:secret_login_form] = ActionController::Parameters.new(
      identifier: @raw_email,
      secret_value: "secret",
    )
    controller.define_singleton_method(:cloudflare_turnstile_validation) { { "success" => false } }
    controller.handle_standard_login

    assert_equal :turnstile_failed, failures.last[:reason]

    controller.define_singleton_method(:cloudflare_turnstile_validation) { { "success" => true } }
    controller.define_singleton_method(:find_user_by_identifier) { |_| target_user }
    controller.define_singleton_method(:session_limit_hard_reject_for?) { |_| true }
    controller.handle_standard_login

    assert_equal :hard_reject, failures.last[:reason]

    controller.define_singleton_method(:session_limit_hard_reject_for?) { |_| false }
    controller.define_singleton_method(:verify_secret_for_sign_in) do |user:, raw_secret:|
      Sign::App::In::SecretsController::SecretVerificationResult.new(
        secret: nil, reason: :secret_mismatch,
        details: { user_id: user.id, raw: raw_secret },
      )
    end
    controller.handle_standard_login

    assert_equal :secret_mismatch, failures.last[:reason]
  end

  test "direct controller success handlers cover mfa and standard redirects" do
    controller = Sign::App::In::SecretsController.new
    session_hash = {}
    params_hash = ActionController::Parameters.new(
      "ri" => "jp",
      "pt" => "encoded-pt",
      "cf-turnstile-response" => "test_token",
    )
    redirects = []
    failures = []

    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => host)
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { params_hash }
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }
    controller.define_singleton_method(:redirect_to_pt_or_default!) { |pt, default_path:|
      redirects << [pt || default_path, {}]
    }
    controller.define_singleton_method(:render_failed_login) { |**kwargs| failures << kwargs }
    controller.define_singleton_method(:render_session_limit_hard_reject) { |**kwargs|
      failures << kwargs.merge(reason: :hard_reject)
    }
    controller.define_singleton_method(:sign_app_configuration_path) { |ri: nil| "/configuration?ri=#{ri}" }
    controller.define_singleton_method(:sign_app_in_session_path) { "/sign/in/session" }
    controller.define_singleton_method(:sign_app_in_checkpoint_path) { |pt: nil, ri: nil|
      "/sign/in/checkpoint?pt=#{pt}&ri=#{ri}"
    }
    controller.define_singleton_method(:t) { |key| key }
    controller.define_singleton_method(:clear_mfa_session!) { session_hash[Sign::App::In::SecretsController::MFA_USER_SESSION_KEY] = nil }

    secret = Struct.new(:id).new(9)

    controller.define_singleton_method(:finalize_mfa_login!) { |_|
      { status: :session_limit_hard_reject, message: "limit", http_status: :conflict }
    }
    controller.handle_successful_mfa(@user, secret)

    assert_equal :hard_reject, failures.last[:reason]

    controller.define_singleton_method(:finalize_mfa_login!) { |_| { status: :restricted } }
    controller.handle_successful_mfa(@user, secret)

    assert_equal [nil, { notice: I18n.t("sign.app.in.session.restricted_notice") }], redirects.last

    controller.define_singleton_method(:finalize_mfa_login!) { |_| { status: :success, redirect_path: "/after" } }
    controller.define_singleton_method(:issue_bulletin!) { true }
    controller.handle_successful_mfa(@user, secret)

    assert_match %r{\A/dashboard}, redirects.last.first

    controller.define_singleton_method(:issue_bulletin!) { false }
    controller.handle_successful_mfa(@user, secret)

    assert_match %r{\A/dashboard\?}, redirects.last.first
    assert_includes redirects.last.first, "ri=jp"
    assert_equal({ notice: "sign.app.authentication.secret.create.success" }, redirects.last.second)

    controller.define_singleton_method(:finalize_mfa_login!) { |_| { status: :unexpected } }
    controller.handle_successful_mfa(@user, secret)

    assert_equal :unexpected, failures.last[:reason]

    controller.define_singleton_method(:establish_signed_in_session!) { |*|
      { status: :mfa_required, redirect_path: "/challenge" }
    }
    controller.process_standard_login(@user)

    assert_equal ["/challenge", { notice: "sign.app.in.mfa.required" }], redirects.last

    controller.define_singleton_method(:establish_signed_in_session!) { |*|
      { status: :session_limit_hard_reject, message: "limit", http_status: :conflict }
    }
    controller.process_standard_login(@user)

    assert_equal :hard_reject, failures.last[:reason]

    controller.define_singleton_method(:establish_signed_in_session!) { |*| { restricted: true } }
    controller.process_standard_login(@user)

    assert_equal ["/sign/in/session", { notice: I18n.t("sign.app.in.session.restricted_notice") }], redirects.last

    controller.define_singleton_method(:establish_signed_in_session!) { |*| { status: :success } }
    controller.define_singleton_method(:issue_bulletin!) { true }
    controller.process_standard_login(@user)

    assert_match %r{\A/dashboard\?}, redirects.last.first

    controller.define_singleton_method(:issue_bulletin!) { false }
    controller.process_standard_login(@user)

    assert_equal ["/dashboard?ri=jp", { notice: "sign.app.authentication.secret.create.success" }], redirects.last
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Sign::In::SecretCredentialsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_secret_credentials, :operator_statuses, :operator_secret_credential_statuses,
           :operator_secret_credential_kinds, :operator_token_binding_methods, :operator_token_kinds,
           :operator_token_statuses, :operator_token_dbsc_statuses, :operator_email_statuses

  setup do
    @host = ENV.fetch("AUTH_STAFF_URL", "auth.org.localhost")
    host! @host
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    @staff = operators(:sample_staff)
    @staff.update!(status_id: OperatorStatus::ACTIVE)
    OperatorToken.where(staff_id: @staff.id).delete_all
    @staff.staff_secret_credentials.destroy_all
    @secret_credential, @raw_secret_credential = OperatorSecretCredential.issue!(
      name: "Sample login",
      staff_id: @staff.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )
    OperatorEmail.find_or_create_by!(staff: @staff, address: "sample_staff_sign_in@example.com") do |email|
      email.staff_email_status_id = OperatorEmailStatus::VERIFIED
    end
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should get new" do
    get new_auth_org_sign_in_secret_credential_url(ri: "jp")

    assert_response :success
    assert_select "label", text: "ID"
    assert_select "input[name='secret_credential_login_form[identifier]'][required]"
    assert_select "input[name='secret_credential_login_form[identifier]'][minlength='16']"
    assert_select "input[name='secret_credential_login_form[identifier]'][maxlength='16']"
    assert_select "input[name='secret_credential_login_form[identifier]'][pattern='[0-9A-FGHJKMNPQRSTVWXYZ]{16}']"
    assert_select "input[name='secret_credential_login_form[identifier]'][autocapitalize='characters']"
    assert_select "input[name='secret_credential_login_form[identifier]'][spellcheck='false']"
    assert_select "input[type='hidden'][name='ri'][value='jp']"
    assert_select "a[href=?]", auth_org_sign_in_path(ri: "jp")
  end

  test "create signs in with staff public_id and secret_credential" do
    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id.downcase,
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_response :redirect
    assert_includes response.headers["Location"], auth_org_sign_in_check_path(ri: "jp")
    assert_equal OperatorSecretCredentialStatus::ACTIVE, @secret_credential.reload.staff_secret_status_id
    assert_predicate @secret_credential.reload.last_used_at, :present?
  end

  test "create falls back to jp when ri is missing" do
    post auth_org_sign_in_secret_credential_url,
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id.downcase,
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_response :redirect
    assert_includes response.headers["Location"], auth_org_sign_in_check_path(ri: "jp")
  end

  test "create canonicalizes invalid ri" do
    post auth_org_sign_in_secret_credential_url(ri: "https://evil.example"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id.downcase,
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_response :redirect
    assert_includes response.headers["Location"], auth_org_sign_in_secret_credential_url(ri: "jp")
    assert_no_match(/evil\.example/, response.headers["Location"])
  end

  test "create keeps permanent secret_credential reusable and rejects repeated login in same session" do
    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id.downcase,
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_response :redirect

    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id.downcase,
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_redirected_to auth_org_dashboard_url(ri: "jp", host: ENV.fetch("AUTH_STAFF_URL", "auth.org.localhost"))

    assert_equal OperatorSecretCredentialStatus::ACTIVE, @secret_credential.reload.staff_secret_status_id
  end

  test "create redirects to dashboard on immediate re-login while already signed in" do
    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id.downcase,
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_response :redirect

    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id.downcase,
             secret_credential_value: @raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_redirected_to auth_org_dashboard_url(ri: "jp", host: ENV.fetch("AUTH_STAFF_URL", "auth.org.localhost"))
  end

  test "create rejects blank form" do
    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE, @secret_credential.reload.staff_secret_status_id
  end

  test "create rejects email identifier" do
    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: "staff_test@example.com",
             secret_credential_value: @raw_secret_credential,
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE, @secret_credential.reload.staff_secret_status_id
  end

  test "create rejects invalid secret_credential" do
    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id,
             secret_credential_value: "wrong-secret_credential-value-000000000000",
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE, @secret_credential.reload.staff_secret_status_id
  end

  test "create rejects non login secret_credential for secret_credential login" do
    OperatorSecretCredentialKind.find_or_create_by!(id: OperatorSecretCredentialKind::NOTHING)
    @secret_credential.update!(staff_secret_kind_id: OperatorSecretCredentialKind::NOTHING)

    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id,
             secret_credential_value: @raw_secret_credential,
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE, @secret_credential.reload.staff_secret_status_id
  end

  test "create rejects reserved staff" do
    reserved_staff = operators(:reserved_staff)
    secret_credential, raw_secret_credential = OperatorSecretCredential.issue!(
      name: "Reserved login",
      staff_id: reserved_staff.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )

    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: reserved_staff.public_id,
             secret_credential_value: raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE, secret_credential.reload.staff_secret_status_id
  end

  test "create rejects withdrawn staff without consuming secret_credential" do
    @staff.update!(status_id: OperatorStatus::ACTIVE, withdrawn_at: Time.current)
    secret_credential, raw_secret_credential = OperatorSecretCredential.issue!(
      name: "Withdrawn login",
      staff_id: @staff.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )

    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id,
             secret_credential_value: raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE, secret_credential.reload.staff_secret_status_id
  end

  test "create renders invalid when log_in returns non-success status" do
    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id,
             secret_credential_value: "wrong-secret_credential",
           },
         }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.org.authentication.secret_credential.create.invalid")
  end

  test "create redirects to session management when logical staff limit is reached despite rotated rows" do
    _secret_credential, raw_secret_credential = OperatorSecretCredential.issue!(
      name: "Rotated session limit login",
      staff_id: @staff.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )
    create_rotated_active_staff_session(@staff, rotations: 4)

    post auth_org_sign_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id,
             secret_credential_value: raw_secret_credential,
           },
           "cf-turnstile-response": "test_token",
         }

    assert_response :redirect
    assert_redirected_to auth_org_sign_in_session_path(ri: "jp")
    assert_equal 0, OperatorToken.where(staff_id: @staff.id, staff_token_status_id: OperatorTokenStatus::RESTRICTED).count
  end

  private

  def create_rotated_active_staff_session(staff, rotations:)
    token = OperatorToken.create!(staff: staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = SignRefreshTokenIssuer.call(refresh_token: refresh)[:refresh_token]
    end
  end
end

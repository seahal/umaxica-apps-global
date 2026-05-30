# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::In::SecretCredentialsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_secret_credentials, :operator_statuses, :operator_secret_credential_statuses,
           :operator_secret_credential_kinds

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    host! @host
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    @staff = operators(:sample_staff)
    @staff.update!(status_id: OperatorStatus::ACTIVE)
    OperatorToken.where(staff_id: @staff.id).delete_all
    @raw_secret_credential = "11111111111111111111111111111111"
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should get new" do
    get new_sign_org_in_secret_credential_url(ri: "jp")

    assert_response :success
    assert_select "label", text: "ID"
    assert_select "input[name='secret_credential_login_form[identifier]'][required]"
    assert_select "input[name='secret_credential_login_form[identifier]'][minlength='16']"
    assert_select "input[name='secret_credential_login_form[identifier]'][maxlength='16']"
    assert_select "input[name='secret_credential_login_form[identifier]'][pattern='[0-9A-FGHJKMNPQRSTVWXYZ]{16}']"
    assert_select "input[name='secret_credential_login_form[identifier]'][autocapitalize='characters']"
    assert_select "input[name='secret_credential_login_form[identifier]'][spellcheck='false']"
  end

  test "create signs in with staff public_id and secret_credential" do
    post sign_org_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id.downcase,
             secret_credential_value: @raw_secret_credential,
           },
         }

    assert_response :redirect
    assert_includes response.headers["Location"], sign_org_in_checkpoint_path(ri: "jp")
    assert_equal OperatorSecretCredentialStatus::ACTIVE,
                 operator_secret_credentials(:sample_login).reload.staff_secret_status_id
    assert_predicate operator_secret_credentials(:sample_login).reload.last_used_at, :present?
  end

  test "create keeps permanent secret_credential reusable and rejects repeated login in same session" do
    post sign_org_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id.downcase,
             secret_credential_value: @raw_secret_credential,
           },
         }

    assert_response :redirect

    post sign_org_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id.downcase,
             secret_credential_value: @raw_secret_credential,
           },
         }

    assert_redirected_to sign_org_dashboard_path(ri: "jp")

    assert_equal OperatorSecretCredentialStatus::ACTIVE,
                 operator_secret_credentials(:sample_login).reload.staff_secret_status_id
  end

  test "create rejects blank form" do
    post sign_org_in_secret_credential_url(ri: "jp"),
         params: { secret_credential_login_form: { identifier: "", secret_credential_value: "" } }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE,
                 operator_secret_credentials(:sample_login).reload.staff_secret_status_id
  end

  test "create rejects email identifier" do
    post sign_org_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: "staff_test@example.com",
             secret_credential_value: @raw_secret_credential,
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE,
                 operator_secret_credentials(:sample_login).reload.staff_secret_status_id
  end

  test "create rejects invalid secret_credential" do
    post sign_org_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id,
             secret_credential_value: "wrong-secret_credential-value-000000000000",
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE,
                 operator_secret_credentials(:sample_login).reload.staff_secret_status_id
  end

  test "create rejects non login secret_credential for secret_credential login" do
    OperatorSecretCredentialKind.find_or_create_by!(id: OperatorSecretCredentialKind::NOTHING)
    operator_secret_credentials(:sample_login).update!(staff_secret_kind_id: OperatorSecretCredentialKind::NOTHING)

    post sign_org_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id,
             secret_credential_value: @raw_secret_credential,
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE,
                 operator_secret_credentials(:sample_login).reload.staff_secret_status_id
  end

  test "create rejects reserved staff" do
    reserved_staff = operators(:reserved_staff)
    secret_credential, raw_secret_credential = OperatorSecretCredential.issue!(
      name: "Reserved login",
      staff_id: reserved_staff.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
    )

    post sign_org_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: reserved_staff.public_id,
             secret_credential_value: raw_secret_credential,
           },
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

    post sign_org_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id,
             secret_credential_value: raw_secret_credential,
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretCredentialStatus::ACTIVE, secret_credential.reload.staff_secret_status_id
  end

  test "create renders invalid when log_in returns non-success status" do
    post sign_org_in_secret_credential_url(ri: "jp"),
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

    post sign_org_in_secret_credential_url(ri: "jp"),
         params: {
           secret_credential_login_form: {
             identifier: @staff.public_id,
             secret_credential_value: raw_secret_credential,
           },
         }

    assert_response :redirect
    assert_redirected_to sign_org_in_session_path(ri: "jp")
    assert_equal 0, OperatorToken.where(staff_id: @staff.id, staff_token_status_id: OperatorTokenStatus::RESTRICTED).count
  end

  private

  def create_rotated_active_staff_session(staff, rotations:)
    token = OperatorToken.create!(staff: staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = Sign::RefreshTokenService.call(refresh_token: refresh)[:refresh_token]
    end
  end
end

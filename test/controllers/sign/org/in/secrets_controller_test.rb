# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::In::SecretsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_secrets, :operator_identity_statuses, :operator_secret_statuses, :operator_secret_kinds

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    host! @host
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    @staff = operators(:sample_staff)
    @staff.update!(status_id: OperatorIdentityStatus::ACTIVE)
    OperatorToken.where(staff_id: @staff.id).delete_all
    @raw_secret = "11111111111111111111111111111111"
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should get new" do
    get new_sign_org_in_secret_url(ri: "jp")

    assert_response :success
    assert_select "label", text: "ID"
    assert_select "input[name='secret_login_form[identifier]'][required]"
    assert_select "input[name='secret_login_form[identifier]'][minlength='16']"
    assert_select "input[name='secret_login_form[identifier]'][maxlength='16']"
    assert_select "input[name='secret_login_form[identifier]'][pattern='[0-9A-FGHJKMNPQRSTVWXYZ]{16}']"
    assert_select "input[name='secret_login_form[identifier]'][autocapitalize='characters']"
    assert_select "input[name='secret_login_form[identifier]'][spellcheck='false']"
  end

  test "create signs in with staff public_id and secret" do
    post sign_org_in_secret_url(ri: "jp"),
         params: {
           secret_login_form: {
             identifier: @staff.public_id.downcase,
             secret_value: @raw_secret,
           },
         }

    assert_response :redirect
    assert_includes response.headers["Location"], sign_org_dashboard_path(ri: "jp")
    assert_equal OperatorSecretStatus::ACTIVE, operator_secrets(:sample_login).reload.staff_secret_status_id
    assert_predicate operator_secrets(:sample_login).reload.last_used_at, :present?
  end

  test "create keeps permanent secret reusable and rejects repeated login in same session" do
    post sign_org_in_secret_url(ri: "jp"),
         params: {
           secret_login_form: {
             identifier: @staff.public_id.downcase,
             secret_value: @raw_secret,
           },
         }

    assert_response :redirect

    post sign_org_in_secret_url(ri: "jp"),
         params: {
           secret_login_form: {
             identifier: @staff.public_id.downcase,
             secret_value: @raw_secret,
           },
         }

    assert_response :unauthorized

    assert_equal OperatorSecretStatus::ACTIVE, operator_secrets(:sample_login).reload.staff_secret_status_id
  end

  test "create rejects blank form" do
    post sign_org_in_secret_url(ri: "jp"),
         params: { secret_login_form: { identifier: "", secret_value: "" } }

    assert_response :unprocessable_content
    assert_equal OperatorSecretStatus::ACTIVE, operator_secrets(:sample_login).reload.staff_secret_status_id
  end

  test "create rejects email identifier" do
    post sign_org_in_secret_url(ri: "jp"),
         params: {
           secret_login_form: {
             identifier: "staff_test@example.com",
             secret_value: @raw_secret,
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretStatus::ACTIVE, operator_secrets(:sample_login).reload.staff_secret_status_id
  end

  test "create rejects invalid secret" do
    post sign_org_in_secret_url(ri: "jp"),
         params: {
           secret_login_form: {
             identifier: @staff.public_id,
             secret_value: "wrong-secret-value-000000000000",
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretStatus::ACTIVE, operator_secrets(:sample_login).reload.staff_secret_status_id
  end

  test "create rejects non login secret for secret login" do
    OperatorSecretKind.find_or_create_by!(id: OperatorSecretKind::NOTHING)
    operator_secrets(:sample_login).update!(staff_secret_kind_id: OperatorSecretKind::NOTHING)

    post sign_org_in_secret_url(ri: "jp"),
         params: {
           secret_login_form: {
             identifier: @staff.public_id,
             secret_value: @raw_secret,
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretStatus::ACTIVE, operator_secrets(:sample_login).reload.staff_secret_status_id
  end

  test "create rejects reserved staff" do
    reserved_staff = operators(:reserved_staff)
    secret, raw_secret = OperatorSecret.issue!(
      name: "Reserved login",
      staff_id: reserved_staff.id,
      staff_secret_kind_id: OperatorSecretKind::LOGIN,
    )

    post sign_org_in_secret_url(ri: "jp"),
         params: {
           secret_login_form: {
             identifier: reserved_staff.public_id,
             secret_value: raw_secret,
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretStatus::ACTIVE, secret.reload.staff_secret_status_id
  end

  test "create rejects withdrawn staff without consuming secret" do
    @staff.update!(status_id: OperatorIdentityStatus::ACTIVE, withdrawn_at: Time.current)
    secret, raw_secret = OperatorSecret.issue!(
      name: "Withdrawn login",
      staff_id: @staff.id,
      staff_secret_kind_id: OperatorSecretKind::LOGIN,
    )

    post sign_org_in_secret_url(ri: "jp"),
         params: {
           secret_login_form: {
             identifier: @staff.public_id,
             secret_value: raw_secret,
           },
         }

    assert_response :unprocessable_content
    assert_equal OperatorSecretStatus::ACTIVE, secret.reload.staff_secret_status_id
  end

  test "create renders invalid when log_in returns non-success status" do
    post sign_org_in_secret_url(ri: "jp"),
         params: {
           secret_login_form: {
             identifier: @staff.public_id,
             secret_value: "wrong-secret",
           },
         }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.org.authentication.secret.create.invalid")
  end

  test "create redirects to session management when logical staff limit is reached despite rotated rows" do
    _secret, raw_secret = OperatorSecret.issue!(
      name: "Rotated session limit login",
      staff_id: @staff.id,
      staff_secret_kind_id: OperatorSecretKind::LOGIN,
    )
    create_rotated_active_staff_session(@staff, rotations: 4)

    post sign_org_in_secret_url(ri: "jp"),
         params: {
           secret_login_form: {
             identifier: @staff.public_id,
             secret_value: raw_secret,
           },
         }

    assert_response :redirect
    assert_redirected_to sign_org_in_session_path(ri: "jp")
    assert_equal "セッション数が上限に達しています。既存セッションを管理してください。", flash[:notice]
    assert_equal 1, OperatorToken.where(staff_id: @staff.id, staff_token_status_id: OperatorTokenStatus::RESTRICTED).count
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

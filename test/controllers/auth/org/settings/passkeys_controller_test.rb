# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Settings::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures_only :operators, :operator_statuses, :operator_passkey_statuses,
                :operator_mfa_levels, :operator_secret_credential_kinds,
                :operator_secret_credential_statuses, :operator_mfa_statuses,
                :operator_visibilities, :operator_token_binding_methods,
                :operator_token_kinds, :operator_token_statuses,
                :operator_token_dbsc_statuses

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @staff.update!(status_id: OperatorStatus::ACTIVE)
    @staff.staff_secret_credentials.destroy_all
    create_operator_passcode!(@staff, name: "recovery 1")
    create_operator_passcode!(@staff, name: "recovery 2")
    @token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    @token.rotate_refresh_token!
    satisfy_staff_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_passkey")
    @host_headers = { "Host" => ENV["ID_STAFF_URL"] || "id.org.localhost" }.freeze
    @headers = @host_headers.merge(
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    )

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should get index" do
    get sign_org_settings_passkeys_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "table"
  end

  test "should get show" do
    passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test_webauthn_id",
      external_id: "test_external_id",
      public_key: "test_public_key",
      name: "Test Passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    get sign_org_settings_passkey_url(passkey, ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "Test Passkey"
  end

  test "should get new" do
    get new_sign_org_settings_passkey_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "h1", I18n.t("sign.org.settings.passkeys.new.page_title")
  end

  test "new allows bootstrap without recovery passcodes" do
    @staff.staff_secret_credentials.destroy_all

    get new_sign_org_settings_passkey_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_equal "text/html", response.media_type
  end

  test "new allows bootstrap when operator multi factor status is unconfigured" do
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
    create_operator_passcode!(operator, name: "bootstrap 1")
    create_operator_passcode!(operator, name: "bootstrap 2")
    token = OperatorToken.create!(staff: operator, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    token.rotate_refresh_token!
    token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)
    headers = @host_headers.merge(
      "X-TEST-CURRENT-STAFF" => operator.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )

    Prosopite.pause do
      get new_sign_org_settings_passkey_url(ri: "jp"), headers: headers
    end

    assert_response :success
    assert_equal OperatorMfaStatus::UNCONFIGURED, operator.reload.mfa_status_id
  end

  test "new requires step up when operator multi factor status is active" do
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "active_status_webauthn_id",
      external_id: "active_status_external_id",
      public_key: "active_status_public_key",
      name: "Active Status Passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    @token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)

    get new_sign_org_settings_passkey_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "settings_passkey", query["scope"]
    assert_equal OperatorMfaStatus::ACTIVE, @staff.reload.mfa_status_id
  end

  test "redirects unauthenticated staff to login" do
    get sign_org_settings_passkeys_url(ri: "jp"), headers: @host_headers

    assert_response :redirect
    uri = URI.parse(jump_rt_url_from_location(response.headers["Location"]))
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal ENV.fetch("ACME_STAFF_URL", "www.org.localhost"), uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal "sign-rp", query["client_id"]
  end

  test "should get edit" do
    passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test_webauthn_id_2",
      external_id: "test_external_id_2",
      public_key: "test_public_key_2",
      name: "Test Passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    get edit_sign_org_settings_passkey_url(passkey, ri: "jp"), headers: @headers

    assert_response :success
  end

  test "update mutates local passkey and redirects to sign" do
    passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test_webauthn_id_3",
      external_id: "test_external_id_3",
      public_key: "test_public_key_3",
      name: "Old Name",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    patch sign_org_settings_passkey_url(passkey, ri: "jp"),
          params: { operator_passkey: { description: "Updated Name" } },
          headers: @headers

    assert_redirected_to sign_org_settings_passkey_path(passkey, ri: "jp")
    assert_equal "Updated Name", passkey.reload.description
  end

  test "update with invalid params renders edit" do
    passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test_webauthn_id_4",
      external_id: "test_external_id_4",
      public_key: "test_public_key_4",
      name: "Test Passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    patch sign_org_settings_passkey_url(passkey, ri: "jp"),
          params: { staff_passkey: { description: "" } },
          headers: @headers

    assert_response :unprocessable_content
    assert_equal "Test Passkey", passkey.reload.description
  end

  test "destroy removes operator passkey on sign settings authority" do
    passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test_webauthn_id_5",
      external_id: "test_external_id_5",
      public_key: "test_public_key_5",
      name: "Test Passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test_webauthn_id_5_extra",
      external_id: "test_external_id_5_extra",
      public_key: "test_public_key_5_extra",
      name: "Extra Passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    assert_difference -> { OperatorPasskey.count }, -1 do
      delete sign_org_settings_passkey_url(passkey, ri: "jp"), headers: @headers
    end

    assert_redirected_to sign_org_settings_passkeys_path(ri: "jp")
  end

  test "other staff passkey returns not found" do
    other_staff = Operator.create!(status_id: OperatorStatus::ACTIVE)
    other_passkey = OperatorPasskey.create!(
      staff: other_staff,
      webauthn_id: "other_webauthn_id",
      external_id: "other_external_id",
      public_key: "other_public_key",
      name: "Other Passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    get sign_org_settings_passkey_url(other_passkey, ri: "jp"), headers: @headers

    assert_response :not_found
  end

  test "create redirects for html requests" do
    assert_no_difference("OperatorPasskey.count") do
      post sign_org_settings_passkeys_url(ri: "jp"), headers: @headers
    end

    assert_redirected_to new_sign_org_settings_passkey_path(ri: "jp")
  end

  test "create returns registration ceremony handoff for api clients" do
    assert_no_difference("OperatorPasskey.count") do
      post sign_org_settings_passkeys_url(ri: "jp"), headers: @headers, as: :json
    end

    assert_response :accepted
    assert_equal "registration_ceremony_required", response.parsed_body["status"]
    assert_equal new_sign_org_settings_passkey_path(ri: "jp"), response.parsed_body["redirect_path"]
  end

  test "verification rejects missing challenge id" do
    post sign_org_settings_passkeys_verification_url(ri: "jp"),
         params: { credential: { id: "cred-id" } },
         headers: @headers,
         as: :json

    assert_response :bad_request
    assert_equal I18n.t("errors.webauthn.challenge_id_required"), response.parsed_body["error"]
  end

  test "update json mutates local passkey" do
    passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test_webauthn_id_json",
      external_id: "test_external_id_json",
      public_key: "test_public_key_json",
      name: "Old Name",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    patch sign_org_settings_passkey_url(passkey, ri: "jp"),
          params: { passkey: { description: "Updated Name" } },
          headers: @headers,
          as: :json

    assert_redirected_to sign_org_settings_passkey_path(passkey, ri: "jp")
    assert_equal "Updated Name", passkey.reload.description
  end

  test "destroy json removes operator passkey on sign settings authority" do
    passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test_webauthn_id_json_destroy",
      external_id: "test_external_id_json_destroy",
      public_key: "test_public_key_json_destroy",
      name: "Delete Me",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test_webauthn_id_json_destroy_extra",
      external_id: "test_external_id_json_destroy_extra",
      public_key: "test_public_key_json_destroy_extra",
      name: "Keep Me",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    assert_difference -> { OperatorPasskey.count }, -1 do
      delete sign_org_settings_passkey_url(passkey, ri: "jp"), headers: @headers, as: :json
    end

    assert_redirected_to sign_org_settings_passkeys_path(ri: "jp")
  end

  private

  def create_operator_passcode!(operator, name:, last_used_at: nil)
    credential = operator.staff_secret_credentials.new(
      name: name,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_identity_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
      last_used_at: last_used_at,
    )
    credential.password = OperatorSecretCredential.generate_raw_secret_credential
    credential.save!
    credential
  end
end

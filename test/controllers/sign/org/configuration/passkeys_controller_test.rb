# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures_only :operators, :operator_identity_statuses, :operator_passkey_statuses

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @staff.update!(status_id: OperatorIdentityStatus::ACTIVE)
    @token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    @token.rotate_refresh_token!
    satisfy_staff_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_passkey")
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
    get sign_org_configuration_passkeys_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "h1", I18n.t("sign.org.configuration.passkeys.index.title")
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

    get sign_org_configuration_passkey_url(passkey, ri: "jp"), headers: @headers

    assert_response :success
    assert_select "body" do |body|
      html = body.first.to_html

      assert_operator html.index(sign_org_configuration_passkeys_path(ri: "jp")), :<, html.index(passkey.description)
    end
  end

  test "should get new" do
    get new_sign_org_configuration_passkey_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "h1", I18n.t("sign.org.configuration.passkeys.new.page_title")
  end

  test "new allows bootstrap when operator multi factor status is unconfigured" do
    operator = Operator.create!(status_id: OperatorIdentityStatus::ACTIVE)
    token = OperatorToken.create!(staff: operator, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    token.rotate_refresh_token!
    token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)
    headers = @host_headers.merge(
      "X-TEST-CURRENT-STAFF" => operator.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )

    Prosopite.pause do
      get new_sign_org_configuration_passkey_url(ri: "jp"), headers: headers
    end

    assert_response :success
    assert_equal OperatorMultiFactorStatus::UNCONFIGURED, operator.reload.multi_factor_status_id
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

    get new_sign_org_configuration_passkey_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "configuration_passkey", query["scope"]
    assert_equal OperatorMultiFactorStatus::ACTIVE, @staff.reload.multi_factor_status_id
  end

  test "redirects unauthenticated staff to login" do
    get sign_org_configuration_passkeys_url(ri: "jp"), headers: @host_headers

    assert_response :redirect
    assert_match new_sign_org_in_path, response.headers["Location"]
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

    get edit_sign_org_configuration_passkey_url(passkey, ri: "jp"), headers: @headers

    assert_response :success
    assert_select "input[name='operator_passkey[description]'][value=?]", passkey.description
  end

  test "should patch update" do
    passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test_webauthn_id_3",
      external_id: "test_external_id_3",
      public_key: "test_public_key_3",
      name: "Old Name",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    patch sign_org_configuration_passkey_url(passkey, ri: "jp"),
          params: { operator_passkey: { description: "Updated Name" } },
          headers: @headers

    assert_redirected_to sign_org_configuration_passkey_path(passkey, ri: "jp")
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

    # Use STUB to stub valid? on the instance loaded by the controller
    if true # Replaced STUB stub with real execution as per G1
      patch sign_org_configuration_passkey_url(passkey, ri: "jp"),
            params: { staff_passkey: { description: "" } },
            headers: @headers

      assert_response :unprocessable_content
    end
  end

  test "should delete destroy" do
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
      delete sign_org_configuration_passkey_url(passkey, ri: "jp"), headers: @headers
    end

    assert_redirected_to sign_org_configuration_passkeys_path(ri: "jp")
  end

  test "cannot access other staff's passkey" do
    other_staff = Operator.create!(status_id: OperatorIdentityStatus::ACTIVE)
    other_passkey = OperatorPasskey.create!(
      staff: other_staff,
      webauthn_id: "other_webauthn_id",
      external_id: "other_external_id",
      public_key: "other_public_key",
      name: "Other Passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    get sign_org_configuration_passkey_url(other_passkey, ri: "jp"), headers: @headers

    assert_response :not_found
  end

  test "create redirects for html requests" do
    I18n.backend.store_translations(:ja, messages: { not_implemented: "Not implemented" })
    post sign_org_configuration_passkeys_url(ri: "jp"), headers: @headers

    assert_redirected_to new_sign_org_configuration_passkey_path(ri: "jp")
  end

  test "create returns json error for api clients" do
    I18n.backend.store_translations(:ja, messages: { not_implemented: "Not implemented" })
    post sign_org_configuration_passkeys_url(ri: "jp"), headers: @headers, as: :json

    assert_response :unprocessable_content
    assert_equal "Not implemented", response.parsed_body["error"]
  end

  test "verification rejects missing challenge id" do
    post verification_sign_org_configuration_passkeys_url(ri: "jp"),
         params: { credential: { id: "cred-id" } },
         headers: @headers,
         as: :json

    assert_response :bad_request
    assert_equal I18n.t("errors.webauthn.challenge_id_required"), response.parsed_body["error"]
  end

  test "update returns ok json when request format is json" do
    passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test_webauthn_id_json",
      external_id: "test_external_id_json",
      public_key: "test_public_key_json",
      name: "Old Name",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    patch sign_org_configuration_passkey_url(passkey, ri: "jp"),
          params: { passkey: { description: "Updated Name" } },
          headers: @headers,
          as: :json

    assert_response :ok
    assert_equal "ok", response.parsed_body["status"]
    assert_equal "Updated Name", passkey.reload.description
  end

  test "destroy returns no content for json requests" do
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

    delete sign_org_configuration_passkey_url(passkey, ri: "jp"), headers: @headers, as: :json

    assert_response :no_content
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Settings::SecretCredentialsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operator_statuses, :operator_secret_credential_statuses, :operator_secret_credential_kinds

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = Operator.create!(
      status_id: OperatorStatus::ACTIVE,
    )
    @staff_passkey = OperatorPasskey.create!(
      staff: @staff,
      name: "Test Passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
      public_key: "test_public_key",
      sign_count: 0,
      external_id: "test_external_id",
      webauthn_id: "test_webauthn_id",
    )
    @token = OperatorToken.create!(staff: @staff)
    satisfy_staff_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_secret_credential")
    @staff_secret_credential = OperatorSecretCredential.create!(
      staff: @staff,
      name: "Test Secret",
      password_digest: "test_password_digest",
      last_used_at: Time.zone.now,
      staff_secret_kind_id: OperatorSecretCredentialKinds::LOGIN,
    )
    CloudflareTurnstile.validation_override_enabled = true
    CloudflareTurnstile.validation_override_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.validation_override_enabled = false
    CloudflareTurnstile.validation_override_response = nil
  end

  def authenticated_headers
    headers = browser_headers.merge(
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    )

    # browser_headers sets an explicit 'Cookie' header which overwrites the cookie jar.
    # We must manually append our verification cookie if it exists.
    csrf_token = cookies["csrf_token"]
    verification_token = cookies[OperatorVerification.cookie_name]
    if verification_token
      headers["Cookie"] = [
        headers["Cookie"],
        ("csrf_token=#{csrf_token}" if csrf_token.present?),
        "#{OperatorVerification.cookie_name}=#{verification_token}",
      ]
        .compact_blank
        .join("; ")
    end

    headers
  end

  test "should get index" do
    get sign_org_settings_secret_credentials_url(ri: "jp"), headers: authenticated_headers

    assert_response :success
    assert_includes response.body, @staff_secret_credential.name
  end

  test "should get show" do
    get sign_org_settings_secret_credential_url(@staff_secret_credential, ri: "jp"), headers: authenticated_headers

    assert_response :success
    assert_includes response.body, @staff_secret_credential.name
  end

  test "should get new" do
    get new_sign_org_settings_secret_credential_url(
      ri: "jp",
    ), headers: authenticated_headers

    assert_response :success
  end

  test "should get edit" do
    get edit_sign_org_settings_secret_credential_url(@staff_secret_credential, ri: "jp"),
        headers: authenticated_headers

    assert_response :success
  end

  test "should create secret_credential and redirect to index" do
    assert_difference("OperatorSecretCredential.count", 1) do
      post sign_org_settings_secret_credentials_url(ri: "jp"),
           params: {
             staff_secret_credential: { name: "New Secret", enabled: true },
             "cf-turnstile-response": "test",
           },
           headers: authenticated_headers
    end

    assert_redirected_to sign_org_settings_secret_credentials_url(
      ri: "jp",
      host: ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
    )
    assert_predicate flash[:notice], :present?
    assert_nil flash[:raw_secret_credential], "raw secret_credential must not be exposed in flash"
  end

  test "should update secret_credential and redirect to index" do
    patch sign_org_settings_secret_credential_url(@staff_secret_credential, ri: "jp"),
          params: { staff_secret_credential: { name: "Updated Secret", enabled: false },
                    "cf-turnstile-response": "test", },
          headers: authenticated_headers

    assert_redirected_to sign_org_settings_secret_credential_path(@staff_secret_credential.public_id, ri: "jp")
    @staff_secret_credential.reload

    assert_equal "Updated Secret", @staff_secret_credential.name
    assert_equal OperatorSecretCredentialStatus::REVOKED, @staff_secret_credential.staff_secret_status_id
  end

  test "destroy soft-deletes secret credential locally" do
    assert_difference(
      -> { OperatorSecretCredential.where(staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE).count },
      -1,
    ) do
      delete sign_org_settings_secret_credential_url(@staff_secret_credential, ri: "jp"),
             params: { "cf-turnstile-response": "test" },
             headers: authenticated_headers
    end

    assert_redirected_to sign_org_settings_secret_credentials_url(
      ri: "jp",
      host: ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
    )
    assert_equal OperatorSecretCredentialStatus::DELETED, @staff_secret_credential.reload.staff_secret_status_id
  end

  test "URL uses public_id not numeric ID" do
    get sign_org_settings_secret_credential_url(@staff_secret_credential, ri: "jp"), headers: authenticated_headers

    # Verify URL contains public_id, not numeric ID
    assert_not_includes request.fullpath, "/#{@staff_secret_credential.id}/"
    assert_includes request.fullpath, "/#{@staff_secret_credential.public_id}"
    assert_response :success
  end

  test "should access secret_credential by public_id" do
    get sign_org_settings_secret_credential_url(@staff_secret_credential.public_id, ri: "jp"),
        headers: authenticated_headers

    assert_response :success
  end

  test "numeric id is not found" do
    get sign_org_settings_secret_credential_url(@staff_secret_credential.id, ri: "jp"),
        headers: authenticated_headers

    assert_response :not_found
  end

  test "create requires successful stealth turnstile" do
    CloudflareTurnstile.validation_override_response = { "success" => false }

    assert_no_difference("OperatorSecretCredential.count") do
      post sign_org_settings_secret_credentials_url(ri: "jp"),
           params: { staff_secret_credential: { name: "Blocked Secret", enabled: true },
                     "cf-turnstile-response": "bad", },
           headers: authenticated_headers
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("turnstile_error")
  end

  test "update requires successful stealth turnstile" do
    CloudflareTurnstile.validation_override_response = { "success" => false }

    patch sign_org_settings_secret_credential_url(@staff_secret_credential, ri: "jp"),
          params: { staff_secret_credential: { name: "Blocked Update", enabled: true },
                    "cf-turnstile-response": "bad", },
          headers: authenticated_headers

    assert_redirected_to sign_org_settings_secret_credential_path(@staff_secret_credential.public_id, ri: "jp")
    assert_equal "Blocked Update", @staff_secret_credential.reload.name
  end

  test "destroy soft-deletes before local turnstile validation" do
    CloudflareTurnstile.validation_override_response = { "success" => false }

    assert_difference(
      -> { OperatorSecretCredential.where(staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE).count },
      -1,
    ) do
      delete sign_org_settings_secret_credential_url(@staff_secret_credential, ri: "jp"),
             params: { "cf-turnstile-response": "bad" },
             headers: authenticated_headers
    end

    assert_redirected_to sign_org_settings_secret_credentials_url(
      ri: "jp",
      host: ENV.fetch("ID_STAFF_URL", "id.org.localhost"),
    )
    assert_equal OperatorSecretCredentialStatus::DELETED, @staff_secret_credential.reload.staff_secret_status_id
  end

  private
end

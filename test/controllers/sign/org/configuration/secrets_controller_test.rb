# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::SecretsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staff_statuses, :staff_secret_statuses, :staff_secret_kinds

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = Staff.create!(
      status_id: StaffStatus::ACTIVE,
    )
    @staff_passkey = StaffPasskey.create!(
      staff: @staff,
      name: "Test Passkey",
      status_id: StaffPasskeyStatus::ACTIVE,
      public_key: "test_public_key",
      sign_count: 0,
      external_id: "test_external_id",
      webauthn_id: "test_webauthn_id",
    )
    @token = StaffToken.create!(staff: @staff)
    satisfy_staff_verification(@token)
    @staff_secret = StaffSecret.create!(
      staff: @staff,
      name: "Test Secret",
      password_digest: "test_password_digest",
      last_used_at: Time.zone.now,
      staff_secret_kind_id: StaffSecret::Kinds::LOGIN,
    )
  end

  def authenticated_headers
    headers = browser_headers.merge(
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    )

    # browser_headers sets an explicit 'Cookie' header which overwrites the cookie jar.
    # We must manually append our verification cookie if it exists.
    verification_token = cookies[StaffVerification.cookie_name]
    if verification_token
      headers["Cookie"] = "#{headers["Cookie"]}; #{StaffVerification.cookie_name}=#{verification_token}"
    end

    headers
  end

  test "should get index" do
    get sign_org_configuration_secrets_url(ri: "jp"), headers: authenticated_headers

    assert_response :success
  end

  test "should get show" do
    get sign_org_configuration_secret_url(@staff_secret, ri: "jp"), headers: authenticated_headers

    assert_response :success
  end

  test "should get new" do
    get new_sign_org_configuration_secret_url(ri: "jp"), headers: authenticated_headers

    assert_response :success
  end

  test "should get edit" do
    get edit_sign_org_configuration_secret_url(@staff_secret, ri: "jp"), headers: authenticated_headers

    assert_response :success
  end

  test "should create secret and redirect to index" do
    satisfy_staff_verification(@token)
    assert_difference("StaffSecret.count", 1) do
      post sign_org_configuration_secrets_url(ri: "jp"),
           params: { staff_secret: { name: "New Secret", enabled: true } },
           headers: authenticated_headers
    end

    assert_redirected_to sign_org_configuration_secrets_url(ri: "jp")
    assert_predicate flash[:notice], :present?
    assert_nil flash[:raw_secret], "raw secret must not be exposed in flash"
  end

  test "should update secret and redirect to index" do
    satisfy_staff_verification(@token)
    patch sign_org_configuration_secret_url(@staff_secret, ri: "jp"),
          params: { staff_secret: { name: "Updated Secret", enabled: false } },
          headers: authenticated_headers

    assert_redirected_to sign_org_configuration_secrets_url(ri: "jp")
    assert_predicate flash[:notice], :present?
    @staff_secret.reload

    assert_equal "Updated Secret", @staff_secret.name
  end

  test "should get destroy" do
    satisfy_staff_verification(@token)
    delete sign_org_configuration_secret_url(@staff_secret, ri: "jp"), headers: authenticated_headers

    assert_response :see_other
    assert_redirected_to sign_org_configuration_secrets_url(ri: "jp")
    assert_predicate flash[:notice], :present?
  end

  test "URL uses public_id not numeric ID" do
    get sign_org_configuration_secret_url(@staff_secret, ri: "jp"), headers: authenticated_headers

    assert_response :success
    # Verify URL contains public_id, not numeric ID
    assert_not_includes request.fullpath, "/#{@staff_secret.id}/"
    assert_includes request.fullpath, "/#{@staff_secret.public_id}"
  end

  test "should access secret by public_id" do
    get sign_org_configuration_secret_url(@staff_secret.public_id, ri: "jp"), headers: authenticated_headers

    assert_response :success
  end

  test "should not access secret by numeric ID" do
    get sign_org_configuration_secret_url(@staff_secret.id, ri: "jp"), headers: authenticated_headers

    assert_response :not_found
  end
end

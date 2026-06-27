# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class OrgStepUpVerificationEnforcerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_chronicle_events, :operator_chronicle_levels,
           :operator_token_statuses, :operator_token_kinds

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = Operator.create!(
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    @token = OperatorToken.create!(
      staff: @staff,
      staff_token_status_id: OperatorTokenStatus::NOTHING,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discarded_at: 1.day.from_now,
      public_id: "stepup_org_#{SecureRandom.hex(4)}",
    )
    @headers = as_staff_headers(@staff, host: @host)
    @headers["X-TEST-SESSION-PUBLIC-ID"] = @token.public_id

    host_value = @host
    @original_trusted_origins = Webauthn.method(:trusted_origins)
    Webauthn.define_singleton_method(:trusted_origins) { ["http://id.org.localhost", "http://#{host_value}"] }
  end

  teardown do
    Webauthn.define_singleton_method(:trusted_origins, @original_trusted_origins) if @original_trusted_origins
  end

  test "GET protected endpoint redirects to setup when configured methods are zero" do
    StepUpConfiguredMethods.stub(:call, []) do
      StepUpAvailableMethods.stub(:call, []) do
        get sign_org_settings_withdrawal_url(ri: "jp"), headers: @headers
      end
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification/setup/new", uri.path
    assert_predicate query["pt"], :present?
  end

  test "GET protected endpoint redirects to verification when configured is non-zero but usable is zero" do
    StepUpConfiguredMethods.stub(:call, [:passkey]) do
      StepUpAvailableMethods.stub(:call, []) do
        get sign_org_settings_withdrawal_url(ri: "jp"), headers: @headers
      end
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_predicate query["pt"], :present?
  end

  test "GET protected endpoint redirects to verification when usable methods exist" do
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "stepup_staff_passkey_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      name: "stepup passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    get sign_org_settings_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)

    assert_equal "/verification", uri.path
  end

  test "POST protected endpoint returns 401 plain when step-up is missing and usable methods exist" do
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "stepup_staff_passkey_post_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      name: "stepup passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    post sign_org_settings_passkeys_options_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
    assert_equal VerificationBase::STEP_UP_REQUIRED_MESSAGE, response.body
  end

  test "successful verification enables protected POST and records audit" do
    return_to = Base64.urlsafe_encode64(sign_org_settings_passkeys_path(ri: "jp"))
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      name: "stepup passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        WebAuthn::Credential.stub(:from_get, passkey_credential_stub("test")) do
          get auth_org_verification_url(scope: "settings_passkey", return_to: return_to, ri: "jp"),
              headers: @headers

          assert_response :success
          get new_sign_org_verification_passkey_url(ri: "jp"), headers: @headers

          post sign_org_verification_passkey_url(ri: "jp"),
               params: { verification: { challenge_id: "test", credential_json: '{"id":"test"}' } },
               headers: @headers
        end
      end
    end

    assert_response :redirect
    assert_redirected_to sign_org_settings_url(ri: "jp")
    assert_not response_has_cookie?(OperatorVerification.cookie_name)

    assert_not OperatorVerification.active.exists?(staff_token_id: @token.id)
    assert_not OperatorChronicle.exists?(
      actor_type: "Operator",
      actor_id: @staff.id,
      event_id: OperatorChronicleEvent::STEP_UP_VERIFIED,
      subject_type: "Operator",
      subject_id: @staff.id,
    )

    post sign_org_settings_passkeys_options_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
  end

  private

  def passkey_credential_stub(id)
    Struct.new(:id, :sign_count) do
      define_method(:verify) do |*|
        true
      end
    end.new(id, 1)
  end
end

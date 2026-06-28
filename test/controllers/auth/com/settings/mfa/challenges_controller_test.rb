# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Settings::Mfa::ChallengesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")
    @host = ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")
    Prosopite.pause do
      VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
      VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
      VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
      VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
      VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
      VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
      VisitorTokenStatus.ensure_defaults!
      VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
      VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
      VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::LOGIN)
      VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::ACTIVE)
    end
    @visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
    VisitorEmail.create!(
      visitor: @visitor,
      address: "com-mfa-#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: "1",
    )
    @visitor.visitor_telephones.create!(
      number: "+819000000004",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::NOTHING,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    satisfy_visitor_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_mfa")
    @passkey = @visitor.visitor_passkeys.create!(
      webauthn_id: "challenge-passkey",
      public_key: "public-key",
      description: "Passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )
    @secret_credential = @visitor.visitor_secret_credentials.create!(
      name: "Recovery",
      password: "a" * 32,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
      visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE,
    )
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "challenge route uses mfa path" do
    assert_equal "/settings/mfa/challenge", URI.parse(auth_com_settings_mfa_challenge_url(ri: "jp")).path
  end

  test "show renders current passkeys and secret_credentials" do
    get auth_com_settings_mfa_challenge_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_includes response.body, "MFA settings"
    assert_includes response.body, I18n.t("sign.app.settings.mfa.show.reset_unavailable")
    assert_select "form", count: 1
  end

  test "update route is not exposed" do
    @visitor.update!(mfa_level_id: VisitorMfaLevel::NOTHING, mfa_level_enabled: false)

    patch auth_com_settings_mfa_challenge_url(ri: "jp"),
          params: { user: { mfa_level_id: VisitorMfaLevel::FULL.to_s } },
          headers: request_headers

    assert_response :not_found
    assert_equal VisitorMfaLevel::NOTHING, @visitor.reload.mfa_level_id
    assert_not_predicate @visitor.reload, :mfa_level_enabled?
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::Mfa::ChallengesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
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
      VisitorSecretKind.find_or_create_by!(id: VisitorSecretKind::LOGIN)
      VisitorSecretStatus.find_or_create_by!(id: VisitorSecretStatus::ACTIVE)
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
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_mfa")
    @passkey = @visitor.visitor_passkeys.create!(
      webauthn_id: "challenge-passkey",
      public_key: "public-key",
      description: "Passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )
    @secret = @visitor.visitor_secrets.create!(
      name: "Recovery",
      password: "a" * 32,
      visitor_secret_kind_id: VisitorSecretKind::LOGIN,
      visitor_secret_status_id: VisitorSecretStatus::ACTIVE,
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
    assert_equal "/configuration/mfa/challenge", URI.parse(sign_com_configuration_mfa_challenge_url(ri: "jp")).path
  end

  test "show renders current passkeys and secrets" do
    get sign_com_configuration_mfa_challenge_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_includes response.body, "MFA settings"
    assert_includes response.body, I18n.t("sign.app.configuration.mfa.show.reset_unavailable")
    assert_select "form", count: 0
  end

  test "update route is not exposed" do
    @visitor.update!(multi_factor_id: VisitorMultiFactor::NOTHING, multi_factor_enabled: false)

    patch sign_com_configuration_mfa_challenge_url(ri: "jp"),
          params: { user: { multi_factor_id: VisitorMultiFactor::FULL.to_s } },
          headers: request_headers

    assert_response :not_found
    assert_equal VisitorMultiFactor::NOTHING, @visitor.reload.multi_factor_id
    assert_not_predicate @visitor.reload, :multi_factor_enabled?
  end
end

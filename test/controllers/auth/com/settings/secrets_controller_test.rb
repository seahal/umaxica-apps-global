# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Settings::SecretsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    host! @host
    Prosopite.pause do
      VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
      VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
      VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
      VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
      VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
      VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
      VisitorTokenStatus.ensure_defaults!
      VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    end

    @visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
    VisitorEmail.create!(
      visitor: @visitor,
      address: "com-recovery-#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: "1",
    )
    @visitor.visitor_telephones.create!(
      number: "+819000000001",
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
    @headers = {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "renders the recovery passcodes title when reveal succeeds" do
    issued = IdentityOneTimeReveal.issue!(
      actor: @visitor,
      session_nonce: @visitor.public_id,
      value: %w(recovery-1 recovery-2),
      purpose: "visitor.recovery_secret_credential",
    )

    get auth_com_settings_secrets_url(ri: "jp", token: issued.token), headers: @headers

    assert_response :success
    assert_select "title", text: /#{I18n.t("sign.recovery_passcodes.show.title")}/
    assert_includes response.body, "recovery-1"
    assert_includes response.body, "recovery-2"
  end

  test "renders the recovery passcodes title when reveal is missing" do
    get auth_com_settings_secrets_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "title", text: /#{I18n.t("sign.recovery_passcodes.show.title")}/
    assert_includes response.body, I18n.t(
      "sign.recovery_passcodes.show.missing",
      default: "These recovery passcodes are no longer available.", # rubocop:disable I18n/RailsI18n/DecorateString
    )
  end
end

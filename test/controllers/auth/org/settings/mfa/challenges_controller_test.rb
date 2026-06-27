# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Settings::Mfa::ChallengesControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_token_statuses, :operator_token_kinds

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @staff.update!(status_id: OperatorStatus::ACTIVE)
    @token = OperatorToken.create!(
      staff: @staff,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    satisfy_staff_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_mfa")
    @headers = {
      "X-TEST-CURRENT-STAFF" => @staff.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
  end

  test "challenge route uses mfa path" do
    assert_equal "/settings/mfa/challenge", URI.parse(sign_org_settings_mfa_challenge_url(ri: "jp")).path
  end

  test "should get show" do
    get sign_org_settings_mfa_challenge_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "h1", I18n.t("sign.app.settings.mfa.show.title")
    assert_select "p", text: I18n.t("sign.app.settings.mfa.show.reset_unavailable")
    assert_select "form[action=?]", sign_org_settings_mfa_challenge_path(ri: "jp"), count: 0
  end

  test "update route is not exposed" do
    @staff.update!(mfa_level_id: OperatorMfaLevel::NOTHING, mfa_level_enabled: false)

    patch sign_org_settings_mfa_challenge_url(ri: "jp"),
          params: { user: { mfa_level_id: OperatorMfaLevel::FULL.to_s } },
          headers: @headers

    assert_response :not_found
    assert_equal OperatorMfaLevel::NOTHING, @staff.reload.mfa_level_id
    assert_not_predicate @staff, :mfa_level_enabled?
  end
end

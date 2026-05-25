# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::Mfa::ChallengesControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_identity_statuses, :operator_token_statuses, :operator_token_kinds

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @staff.update!(status_id: OperatorIdentityStatus::ACTIVE)
    @token = OperatorToken.create!(
      staff: @staff,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    satisfy_staff_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_mfa")
    @headers = {
      "X-TEST-CURRENT-STAFF" => @staff.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
  end

  test "challenge route uses mfa path" do
    assert_equal "/configuration/mfa/challenge", URI.parse(sign_org_configuration_mfa_challenge_url(ri: "jp")).path
  end

  test "should get show" do
    get sign_org_configuration_mfa_challenge_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "h1", I18n.t("sign.app.configuration.mfa.show.title")
    assert_select "p", text: I18n.t("sign.app.configuration.mfa.show.reset_unavailable")
    assert_select "form[action=?]", sign_org_configuration_mfa_challenge_path(ri: "jp"), count: 0
  end

  test "update route is not exposed" do
    @staff.update!(multi_factor_id: OperatorMultiFactor::NOTHING, multi_factor_enabled: false)

    patch sign_org_configuration_mfa_challenge_url(ri: "jp"),
          params: { user: { multi_factor_id: OperatorMultiFactor::FULL.to_s } },
          headers: @headers

    assert_response :not_found
    assert_equal OperatorMultiFactor::NOTHING, @staff.reload.multi_factor_id
    assert_not_predicate @staff, :multi_factor_enabled?
  end
end

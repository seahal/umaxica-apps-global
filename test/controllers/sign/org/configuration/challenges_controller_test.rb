# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::ChallengesControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses, :staff_token_statuses, :staff_token_kinds

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = staffs(:one)
    @staff.update!(status_id: OperatorIdentityStatus::ACTIVE)
    @token = OperatorToken.create!(
      staff: @staff,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    satisfy_staff_verification(@token)
    @headers = {
      "X-TEST-CURRENT-STAFF" => @staff.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
  end

  test "should get show" do
    get sign_org_configuration_challenge_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "h1", I18n.t("sign.app.configuration.mfa.show.title")
  end

  test "update toggles multi_factor_id" do
    @staff.update!(multi_factor_id: OperatorMultiFactor::NOTHING, multi_factor_enabled: false)

    patch sign_org_configuration_challenge_url(ri: "jp"),
          params: { user: { multi_factor_id: OperatorMultiFactor::FULL.to_s } },
          headers: @headers

    assert_redirected_to sign_org_configuration_challenge_url(ri: "jp")
    assert_equal OperatorMultiFactor::FULL, @staff.reload.multi_factor_id
    assert_predicate @staff, :multi_factor_enabled?
  end

  test "update rejects unsupported multi_factor_id" do
    @staff.update!(multi_factor_id: OperatorMultiFactor::NOTHING, multi_factor_enabled: false)

    patch sign_org_configuration_challenge_url(ri: "jp"),
          params: { user: { multi_factor_id: OperatorMultiFactor::WEAK.to_s } },
          headers: @headers

    assert_response :unprocessable_content
    assert_equal OperatorMultiFactor::NOTHING, @staff.reload.multi_factor_id
  end
end

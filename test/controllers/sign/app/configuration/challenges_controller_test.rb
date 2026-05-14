# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Configuration::ChallengesControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses, :user_token_statuses, :user_token_kinds

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    @token = UserToken.create!(
      user_id: @user.id,
    )
    satisfy_user_verification(@token)
    @headers = {
      "X-TEST-CURRENT-USER" => @user.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
  end

  test "should get show" do
    get sign_app_configuration_challenge_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "h1", I18n.t("sign.app.configuration.mfa.show.title")
  end

  test "show redirects to verification when step-up is not satisfied" do
    cookies.delete(UserVerification.cookie_name)
    @token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)

    get sign_app_configuration_challenge_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "configuration_mfa", query["scope"]
    assert_equal "jp", query["ri"]
    assert_predicate query["rt"], :present?
  end

  test "update toggles multi_factor_id" do
    @user.update!(multi_factor_id: UserMultiFactor::NOTHING, multi_factor_enabled: false)

    patch sign_app_configuration_challenge_url(ri: "jp"),
          params: { user: { multi_factor_id: UserMultiFactor::FULL.to_s } },
          headers: @headers

    assert_redirected_to sign_app_configuration_challenge_url(ri: "jp")
    assert_equal UserMultiFactor::FULL, @user.reload.multi_factor_id
    assert_predicate @user, :multi_factor_enabled?
  end

  test "update rejects unsupported multi_factor_id" do
    @user.update!(multi_factor_id: UserMultiFactor::NOTHING, multi_factor_enabled: false)

    patch sign_app_configuration_challenge_url(ri: "jp"),
          params: { user: { multi_factor_id: UserMultiFactor::WEAK.to_s } },
          headers: @headers

    assert_response :unprocessable_content
    assert_equal UserMultiFactor::NOTHING, @user.reload.multi_factor_id
  end
end

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

  test "update toggles multi_factor_enabled" do
    @user.update!(multi_factor_enabled: false)

    patch sign_app_configuration_challenge_url(ri: "jp"),
          params: { user: { multi_factor_enabled: "1" } },
          headers: @headers

    assert_redirected_to sign_app_configuration_challenge_url(ri: "jp")
    assert @user.reload.multi_factor_enabled
  end
end

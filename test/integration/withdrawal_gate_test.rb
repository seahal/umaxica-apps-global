# typed: false
# frozen_string_literal: true

require "test_helper"

class WithdrawalGateTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses, :user_token_kinds, :user_token_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host

    @deactivated_user = users(:one)
    @deactivated_user.update!(
      withdrawal_started_at: 1.day.ago,
      deactivated_at: Time.current,
      scheduled_purge_at: 31.days.from_now,
    )
    UserToken.where(user: @deactivated_user).delete_all

    @token = UserToken.create!(
      user: @deactivated_user,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      public_id: "deactivated_#{SecureRandom.hex(4)}",
      refresh_expires_at: 1.day.from_now,
    )
    satisfy_user_verification(@token)

    @headers = {
      "X-TEST-CURRENT-USER" => @deactivated_user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze
  end

  test "deactivated user accessing normal page redirects to configuration edit" do
    get sign_app_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :redirect
    assert_redirected_to edit_sign_app_configuration_path(ri: "jp")
  end

  test "deactivated user can access allowlisted pages" do
    get new_sign_app_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :success

    get edit_sign_app_configuration_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "deactivated user accessing API returns 403" do
    get sign_app_configuration_sessions_url(ri: "jp"), headers: @headers.merge("Accept" => "application/json")

    assert_response :forbidden
    json_response = response.parsed_body

    assert_equal "WITHDRAWAL_REQUIRED", json_response["error"]
  end

  test "normal user can access pages without withdrawal gate" do
    normal_user = users(:two)
    normal_user.update!(status_id: UserStatus::NOTHING)

    normal_token = UserToken.create!(
      user: normal_user,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      public_id: "normal_#{SecureRandom.hex(4)}",
      refresh_expires_at: 1.day.from_now,
    )
    satisfy_user_verification(normal_token)

    headers = {
      "X-TEST-CURRENT-USER" => normal_user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => normal_token.public_id,
    }

    get sign_app_configuration_sessions_url(ri: "jp"), headers: headers

    assert_response :success
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class VerificationSessionsTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses, :user_one_time_password_statuses, :user_token_statuses, :user_token_kinds
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host

    @user = users(:one)

    @token = UserToken.create!(
      user: @user,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      public_id: "verify_#{SecureRandom.hex(4)}",
      refresh_expires_at: 1.day.from_now,
    )
    @token.update!(created_at: 1.hour.ago)

    @headers = {
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze

    UserOneTimePassword.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
  end

  test "GET within 15 minutes skips verification" do
    @token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "configuration_email")

    return_to = Base64.urlsafe_encode64(sign_app_configuration_path(ri: "jp"))
    get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
        headers: @headers

    get new_sign_app_verification_totp_url(ri: "jp"), headers: @headers

    assert_response :redirect
    assert_redirected_to sign_app_verification_url(ri: "jp")
  end

  test "POST within 30 minutes skips verification" do
    @token.update!(last_step_up_at: 20.minutes.ago, last_step_up_scope: "configuration_email")

    return_to = Base64.urlsafe_encode64(sign_app_configuration_path(ri: "jp"))
    get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
        headers: @headers

    if true # Replaced STUB stub with real execution as per G1
      post sign_app_verification_totp_url(ri: "jp"),
           params: { verification: { code: "000000" } },
           headers: @headers
    end

    assert_response :redirect
    assert_redirected_to sign_app_verification_url(ri: "jp")
  end
end

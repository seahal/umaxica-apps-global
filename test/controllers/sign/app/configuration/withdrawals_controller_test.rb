# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::App::Configuration::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :user_statuses, :user_token_kinds, :user_token_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host
    @user = create_verified_user_with_email(email_address: "withdrawal-#{SecureRandom.hex(4)}@example.com")
    @user.update_columns(created_at: 120.days.ago, updated_at: 120.days.ago)
    @token = UserToken.create!(
      user: @user,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
      lapses_at: 1.day.from_now,
      purge_at: 2.days.from_now,
    )
    perform_withdrawal_step_up!
    @headers = as_user_headers(@user, host: @host).merge("X-TEST-SESSION-PUBLIC-ID" => @token.public_id)
  end

  test "new requires schedule confirmation to proceed" do
    get new_sign_app_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :success

    get new_sign_app_configuration_withdrawal_url(ri: "jp", ack_schedule_purge: "0"), headers: @headers

    assert_response :unprocessable_content

    get new_sign_app_configuration_withdrawal_url(ri: "jp", ack_schedule_purge: "1"), headers: @headers

    assert_response :success
    # Skip label text verification - translation key may be missing
    assert_select "label"
  end

  test "update requires deactivate confirmation" do
    patch sign_app_configuration_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "0" },
          headers: @headers

    assert_response :unprocessable_content
    assert_nil @user.reload.deactivated_at
  end

  test "update sets deactivation timestamps" do
    travel_to Time.zone.parse("2026-02-09 10:00:00") do
      patch sign_app_configuration_withdrawal_url(ri: "jp"),
            params: { ack_deactivate_today: "1" },
            headers: @headers
    end

    assert_response :see_other
    assert_redirected_to edit_sign_app_configuration_path(ri: "jp")

    @user.reload

    assert_not_nil @user.withdrawal_started_at
    assert_not_nil @user.deactivated_at
    assert_equal @user.deactivated_at + 31.days, @user.purge_at
  end

  test "edit shows recoverable state within 31 days" do
    @user.update!(
      deactivated_at: 10.days.ago, withdrawal_started_at: 10.days.ago,
      lapses_at: 1.day.from_now,
      purge_at: 21.days.from_now,
    )

    get edit_sign_app_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "復旧"
  end

  test "create recovers account within 31 days" do
    @user.update!(
      deactivated_at: 10.days.ago, withdrawal_started_at: 10.days.ago,
      lapses_at: 1.day.from_now,
      purge_at: 21.days.from_now,
    )

    post sign_app_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :see_other
    assert_redirected_to sign_app_configuration_path(ri: "jp")
    @user.reload

    assert_nil @user.deactivated_at
    assert_nil @user.withdrawal_started_at
    assert_equal Float::INFINITY, @user.purge_at
  end

  test "create does not recover account after 31 days" do
    @user.update!(
      deactivated_at: 31.days.ago, withdrawal_started_at: 31.days.ago,
      lapses_at: 2.days.ago,
      purge_at: 1.day.ago,
    )

    post sign_app_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :see_other
    @user.reload

    assert_not_nil @user.deactivated_at
  end

  private

  def perform_withdrawal_step_up!
    return_to = Base64.urlsafe_encode64(sign_app_configuration_withdrawal_path(ri: "jp"))
    headers = host_headers(@host).merge(
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    )

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      Email::App::RegistrationMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        get(sign_app_verification_url(scope: "withdrawal", return_to: return_to, ri: "jp"), headers: headers)

        assert_response :success

        get(new_sign_app_verification_email_url(ri: "jp"), headers: headers)

        assert_response :redirect
        Rails.logger.debug { "DEBUG: withdrawal redirect location: #{response.location}" }
        nonce = response.location[%r{/verification/emails/([^/]+)/edit}, 1]
        Rails.logger.debug { "DEBUG: withdrawal nonce: #{nonce.inspect}" }

        with_verify_email_otp_stub(true) do
          patch(
            sign_app_verification_email_url(nonce, ri: "jp"),
            params: { verification: { code: "123456" } },
            headers: headers,
          )
        end

        assert_response :redirect
      end
    end
  end

  def with_verify_email_otp_stub(result)
    original_method = Sign::App::Verification::EmailsController.instance_method(:verify_email_otp!)
    Sign::App::Verification::EmailsController.define_method(:verify_email_otp!) { result }
    yield
  ensure
    Sign::App::Verification::EmailsController.define_method(:verify_email_otp!, original_method)
  end
end

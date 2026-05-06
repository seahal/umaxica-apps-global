# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Configuration::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses, :user_token_statuses, :user_token_kinds, :user_email_statuses,
           :user_telephone_statuses, :user_passkey_statuses

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    @token = UserToken.create!(
      user_id: @user.id,
    )
    satisfy_user_verification(@token)
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "should get index" do
    get sign_app_configuration_emails_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "index displays verified status" do
    email = UserEmail.create!(
      address: "verified@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    get sign_app_configuration_emails_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_includes @response.body, "認証済み"
    assert_includes @response.body, email.address
  end

  test "destroy removes email when not last method" do
    email1 = UserEmail.create!(
      address: "delete1@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
    UserEmail.create!(
      address: "delete2@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    assert_difference("UserEmail.count", -1) do
      delete sign_app_configuration_email_url(email1, ri: "jp"), headers: request_headers
    end

    assert_response :see_other
  end

  test "destroy allows removing last email when telephone and passkey are present" do
    user = User.create!(status_id: UserStatus::NOTHING, public_id: "ero_#{SecureRandom.hex(4)}")
    token = UserToken.create!(
      user_id: user.id,
    )
    satisfy_user_verification(token)
    email = UserEmail.create!(
      address: "email_rule_ok@example.com",
      user: user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
    UserTelephone.create!(
      number: "+15550001111",
      user: user,
      user_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )
    UserPasskey.create!(
      user: user,
      webauthn_id: "email_rule_ok_pk_#{SecureRandom.hex(6)}",
      public_key: "pk_#{SecureRandom.hex(6)}",
      sign_count: 0,
      description: "pk",
      status_id: UserPasskeyStatus::ACTIVE,
    )

    headers = {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => user.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_difference("UserEmail.count", -1) do
      delete sign_app_configuration_email_url(email, ri: "jp"), headers: headers
    end

    assert_response :see_other
  end

  test "destroy blocks removing last email when telephone exists but no passkey or social" do
    user = User.create!(status_id: UserStatus::NOTHING, public_id: "ern_#{SecureRandom.hex(4)}")
    token = UserToken.create!(
      user_id: user.id,
    )
    satisfy_user_verification(token)
    email = UserEmail.create!(
      address: "email_rule_ng@example.com",
      user: user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
    UserTelephone.create!(
      number: "+15550001112",
      user: user,
      user_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )

    headers = {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => user.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_no_difference("UserEmail.count") do
      delete sign_app_configuration_email_url(email, ri: "jp"), headers: headers
    end

    assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
  end

  test "destroy blocks removing an undeletable email" do
    email = UserEmail.create!(
      address: "protected@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
      undeletable: true,
    )
    UserEmail.create!(
      address: "other@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    assert_no_difference("UserEmail.count") do
      delete sign_app_configuration_email_url(email, ri: "jp"), headers: request_headers
    end

    assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.email.destroy.protected"), flash[:alert]
  end
end

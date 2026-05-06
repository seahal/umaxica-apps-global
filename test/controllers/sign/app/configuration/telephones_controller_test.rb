# typed: false
# frozen_string_literal: true

require "test_helper"

require "ostruct"

class Sign::App::Configuration::TelephonesControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses, :user_telephone_statuses, :user_email_statuses
  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV["ID_SERVICE_URL"] || "id.app.localhost"
    @user = users(:one)
    @token = UserToken.create!(
      user_id: @user.id,
    )
    satisfy_user_verification(@token)
    @telephone = OpenStruct.new(id: "1")
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "should get index" do
    get sign_app_configuration_telephones_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "should show up link on index page" do
    get sign_app_configuration_telephones_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp")
  end

  test "should get new" do
    get new_sign_app_configuration_telephones_registration_url(ri: "jp"),
        headers: request_headers

    assert_response :success
  end

  test "create registers telephone without signup confirmation params" do
    assert_enqueued_jobs 1, only: SmsDeliveryJob do
      assert_difference("UserTelephone.count", 1) do
        post sign_app_configuration_telephones_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000008" } },
             headers: request_headers
      end
    end

    created = UserTelephone.order(created_at: :desc).first

    assert_redirected_to edit_sign_app_configuration_telephone_url(created.id, ri: "jp")
  end

  test "create reuses existing telephone and sends sms when same number is submitted again" do
    existing = UserTelephone.create!(
      number: "+10000000012",
      user: @user,
      user_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )

    assert_enqueued_jobs 1, only: SmsDeliveryJob do
      assert_no_difference("UserTelephone.count") do
        post sign_app_configuration_telephones_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000012" } },
             headers: request_headers
      end
    end

    assert_redirected_to edit_sign_app_configuration_telephone_url(existing.id, ri: "jp")
  end

  test "destroy removes telephone when not last method" do
    tel1 = UserTelephone.create!(
      number: "+10000000000",
      user: @user,
      user_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )
    UserTelephone.create!(
      number: "+10000000001",
      user: @user,
      user_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )

    assert_difference("UserTelephone.count", -1) do
      delete sign_app_configuration_telephone_url(tel1, ri: "jp"), headers: request_headers
    end

    assert_response :see_other
    assert_predicate flash[:notice], :present?
  end

  test "destroy blocks removal when last method" do
    user = User.create!(status_id: UserStatus::NOTHING)
    token = UserToken.create!(
      user_id: user.id,
    )
    satisfy_user_verification(token)
    telephone = UserTelephone.create!(
      number: "+10000000002",
      user: user,
      user_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )

    assert_no_difference("UserTelephone.count") do
      delete sign_app_configuration_telephone_url(telephone, ri: "jp"),
             headers: {
               "Host" => @host,
               "X-TEST-CURRENT-USER" => user.id,
               "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
             }
    end

    assert_redirected_to sign_app_configuration_telephones_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.telephone.destroy.last_method"), flash[:alert]
  end

  test "destroy allows removing last telephone when verified email exists" do
    user = User.create!(status_id: UserStatus::NOTHING, public_id: "tel_rule_ok_#{SecureRandom.hex(4)}")
    token = UserToken.create!(
      user_id: user.id,
    )
    satisfy_user_verification(token)
    telephone = UserTelephone.create!(
      number: "+10000000005",
      user: user,
      user_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )
    UserEmail.create!(
      user: user,
      address: "telephone_rule_ok@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    headers = {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => user.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_difference("UserTelephone.count", -1) do
      delete sign_app_configuration_telephone_url(telephone, ri: "jp"), headers: headers
    end

    assert_response :see_other
  end

  test "destroy rejects other user's public_id" do
    other_user = User.create!(status_id: UserStatus::NOTHING)
    other_telephone = UserTelephone.create!(
      number: "+10000000003",
      user: other_user,
      user_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )

    assert_no_difference("UserTelephone.count") do
      delete sign_app_configuration_telephone_url(other_telephone, ri: "jp"),
             headers: request_headers

      assert_response :not_found
    end
  end

  test "destroy rejects missing public_id" do
    assert_no_difference("UserTelephone.count") do
      delete sign_app_configuration_telephone_url("missing-public-id", ri: "jp"),
             headers: request_headers

      assert_response :not_found
    end
  end
end

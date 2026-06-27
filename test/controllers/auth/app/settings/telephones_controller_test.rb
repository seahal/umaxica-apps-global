# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Settings::TelephonesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_telephone_statuses
  include ActiveJob::TestHelper
  include AuthHelpers

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host
    @user = clients(:one)
    @token = ClientToken.create!(user_id: @user.id)
    satisfy_user_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_telephone")
    set_access_cookie(jwt_access_token_for(@user, host: @host, session_public_id: @token.public_id))
  end

  def request_headers
    as_user_headers(@user, host: @host, session_public_id: @token.public_id)
  end

  test "sign settings telephones index redirects to acme authority" do
    get sign_app_settings_telephones_url(ri: "jp")

    assert_response :success
    assert_select "table"
  end

  test "legacy sign settings telephone edit remains ceremony account-binding flow" do
    telephone = ClientTelephone.create!(
      number: "+10000000031",
      user: @user,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    get edit_sign_app_settings_telephone_url(telephone.public_id, ri: "jp"), headers: request_headers

    assert_response :success
    assert_select(
      "form[action=?]",
      sign_app_settings_telephone_path(telephone.public_id, ri: "jp"),
      count: 1,
    )
  end

  test "sign settings telephone destroy redirects without local account mutation" do
    telephone = ClientTelephone.create!(
      number: "+10000000000",
      user: @user,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    assert_no_difference("ClientTelephone.count") do
      delete sign_app_settings_telephone_url(telephone.public_id, ri: "jp")
    end

    assert_redirected_to sign_app_settings_telephones_url(ri: "jp")
  end

  test "legacy sign settings telephone new remains ceremony entry" do
    get new_sign_app_settings_telephone_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "legacy sign settings telephone create starts ceremony and redirects to registration edit" do
    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_difference("ClientTelephone.count", 1) do
        post sign_app_settings_telephones_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000008" } },
             headers: request_headers
      end
    end

    assert_redirected_to edit_sign_app_settings_telephones_registration_url(ri: "jp")
  end
end

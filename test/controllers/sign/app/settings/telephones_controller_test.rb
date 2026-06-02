# typed: false
# frozen_string_literal: true

require "test_helper"

require "ostruct"

class Sign::App::Settings::TelephonesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_telephone_statuses, :client_email_statuses,
           :client_chronicle_events, :client_chronicle_levels
  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV["ID_SERVICE_URL"] || "id.app.localhost"
    @user = clients(:one)
    @token = ClientToken.create!(
      user_id: @user.id,
    )
    satisfy_user_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_telephone")
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
    get sign_app_settings_telephones_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "should show up link on index page" do
    get sign_app_settings_telephones_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_select "a[href=?]", sign_app_settings_path(ri: "jp")
  end

  test "should get new" do
    get new_sign_app_settings_telephones_registration_url(ri: "jp"),
        headers: request_headers

    assert_response :success
  end

  test "create registers telephone without signup confirmation params" do
    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_difference("ClientTelephone.count", 1) do
        post sign_app_settings_telephones_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000008" } },
             headers: request_headers
      end
    end

    created = ClientTelephone.order(created_at: :desc).first

    assert_redirected_to edit_sign_app_settings_telephone_url(created.id, ri: "jp")
  end

  test "create reuses existing telephone and sends sms when same number is submitted again" do
    existing = ClientTelephone.create!(
      number: "+10000000012",
      user: @user,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_no_difference("ClientTelephone.count") do
        post sign_app_settings_telephones_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000012" } },
             headers: request_headers
      end
    end

    assert_redirected_to edit_sign_app_settings_telephone_url(existing.id, ri: "jp")
  end

  test "destroy removes telephone when not last method" do
    tel1 = ClientTelephone.create!(
      number: "+10000000000",
      user: @user,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    ClientTelephone.create!(
      number: "+10000000001",
      user: @user,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    assert_difference("ClientTelephone.count", -1) do
      assert_difference(
        -> {
          ClientChronicle.where(
            actor_type: "Client",
            actor_id: @user.id,
            subject_type: "ClientTelephone",
            subject_id: tel1.id,
            event_id: ClientChronicleEvent::TELEPHONE_REMOVED,
          ).count
        },
        1,
      ) do
        delete sign_app_settings_telephone_url(tel1, ri: "jp"), headers: request_headers
      end
    end

    assert_response :see_other
    assert_predicate flash[:notice], :present?
  end

  test "destroy rejects other user's public_id" do
    other_user = Client.create!(status_id: ClientStatus::NOTHING)
    other_telephone = ClientTelephone.create!(
      number: "+10000000003",
      user: other_user,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    assert_no_difference("ClientTelephone.count") do
      delete sign_app_settings_telephone_url(other_telephone, ri: "jp"),
             headers: request_headers

      assert_response :not_found
    end
  end

  test "destroy rejects missing public_id" do
    assert_no_difference("ClientTelephone.count") do
      delete sign_app_settings_telephone_url("missing-public-id", ri: "jp"),
             headers: request_headers

      assert_response :not_found
    end
  end
end

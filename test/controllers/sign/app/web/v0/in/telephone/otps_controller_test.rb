# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Web::V0::In::Telephone::OtpsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "recent issued returns 429 with retry_after and header" do
    telephone = "+8190#{rand(10_000_000..99_999_999)}"
    hmac = Occurrence::Hmac.digest(kind: :telephone, body: telephone)
    TelephoneOccurrence.where(body: hmac).delete_all
    TelephoneOccurrence.create!(
      body: hmac,
      status_id: TelephoneOccurrenceStatus::ACTIVE,
      memo: "purpose=in issued=#{Time.current.to_i}",
    )

    post sign_app_web_v0_in_telephone_otp_path,
         params: { state: state_for(telephone) },
         headers: { "Host" => @host },
         as: :json

    assert_response :too_many_requests
    assert_not response.parsed_body["resendable"]
    assert_operator response.parsed_body["retry_after"], :>, 0
    assert_equal response.parsed_body["retry_after"].to_s, response.headers["Retry-After"]
  end

  test "after cooldown returns 200 and logs issued occurrence" do
    user = users(:one)
    telephone = "+8190#{rand(10_000_000..99_999_999)}"
    user.user_telephones.create!(number: telephone, user_telephone_status_id: UserTelephoneStatus::VERIFIED)

    hmac = Occurrence::Hmac.digest(kind: :telephone, body: telephone)
    TelephoneOccurrence.where(body: hmac).delete_all
    TelephoneOccurrence.create!(
      body: hmac,
      status_id: TelephoneOccurrenceStatus::ACTIVE,
      memo: "purpose=in issued=#{31.seconds.ago.to_i}",
    )

    assert_enqueued_jobs 1, only: SmsDeliveryJob do
      post sign_app_web_v0_in_telephone_otp_path,
           params: { state: state_for(telephone) },
           headers: { "Host" => @host },
           as: :json
    end

    assert_response :ok
    assert response.parsed_body["resendable"]
    assert_equal 0, response.parsed_body["retry_after"]

    occurrence = TelephoneOccurrence.find_by(body: hmac)

    assert_not_nil occurrence
    assert_equal TelephoneOccurrenceStatus::ACTIVE, occurrence.status_id
    assert_includes occurrence.memo, "purpose=in"
    assert_match(/issued=[0-9,]+/, occurrence.memo)
  end

  test "success rotates OTP so only latest code verifies" do
    user = users(:one)
    telephone_record = user.user_telephones.create!(
      number: "+8190#{rand(10_000_000..99_999_999)}",
      user_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )

    old_private_key = ROTP::Base32.random_base32
    old_counter = 2048
    old_code = ROTP::HOTP.new(old_private_key).at(old_counter).to_s
    telephone_record.store_otp(old_private_key, old_counter, 12.minutes.from_now.to_i)

    post sign_app_web_v0_in_telephone_otp_path,
         params: { state: state_for(telephone_record.number) },
         headers: { "Host" => @host },
         as: :json

    assert_response :ok

    telephone_record.reload
    otp_data = telephone_record.get_otp

    assert_not_nil otp_data

    new_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s
    verifier = Class.new { include Common::Otp }.new

    assert_not verifier.send(:verify_otp_code, telephone_record, old_code)[:success]
    assert verifier.send(:verify_otp_code, telephone_record, new_code)[:success]
  end

  private

  def state_for(telephone)
    Sign::In::OtpResendState.issue(kind: :telephone, target: telephone)
  end
end

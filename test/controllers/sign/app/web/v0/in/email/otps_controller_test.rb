# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Web::V0::In::Email::OtpsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    ActionMailer::Base.deliveries.clear
  end

  test "recent issued returns 429 with retry_after and header" do
    email = "retry_#{SecureRandom.hex(4)}@example.com"
    hmac = Occurrence::Hmac.digest(kind: :email, body: email)
    EmailOccurrence.where(body: hmac).delete_all
    EmailOccurrence.create!(
      body: hmac,
      status_id: EmailOccurrenceStatus::ACTIVE,
      memo: "purpose=in issued=#{Time.current.to_i}",
    )

    post sign_app_web_v0_in_email_otp_path,
         params: { state: state_for(email) },
         headers: { "Host" => @host },
         as: :json

    assert_response :too_many_requests
    assert_not response.parsed_body["resendable"]
    assert_operator response.parsed_body["retry_after"], :>, 0
    assert_equal response.parsed_body["retry_after"].to_s, response.headers["Retry-After"]
  end

  test "after cooldown returns 200 and logs issued occurrence" do
    user = users(:one)
    email = "ok_#{SecureRandom.hex(4)}@example.com"
    user.user_emails.create!(address: email, user_email_status_id: UserEmailStatus::VERIFIED)

    hmac = Occurrence::Hmac.digest(kind: :email, body: email)
    EmailOccurrence.where(body: hmac).delete_all
    EmailOccurrence.create!(
      body: hmac,
      status_id: EmailOccurrenceStatus::ACTIVE,
      memo: "purpose=in issued=#{31.seconds.ago.to_i}",
    )

    assert_difference -> { ActionMailer::Base.deliveries.count }, 1 do
      perform_enqueued_jobs do
        post sign_app_web_v0_in_email_otp_path,
             params: { state: state_for(email) },
             headers: { "Host" => @host },
             as: :json
      end
    end

    assert_response :ok
    assert response.parsed_body["resendable"]
    assert_equal 0, response.parsed_body["retry_after"]

    occurrence = EmailOccurrence.find_by(body: hmac)

    assert_not_nil occurrence
    assert_equal EmailOccurrenceStatus::ACTIVE, occurrence.status_id
    assert_includes occurrence.memo, "purpose=in"
    assert_match(/issued=[0-9,]+/, occurrence.memo)
  end

  test "success rotates OTP so only latest code verifies" do
    user = users(:one)
    email_record = user.user_emails.create!(
      address: "rotate_#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    old_private_key = ROTP::Base32.random_base32
    old_counter = 1024
    old_code = ROTP::HOTP.new(old_private_key).at(old_counter).to_s
    email_record.store_otp(old_private_key, old_counter, 12.minutes.from_now.to_i)

    post sign_app_web_v0_in_email_otp_path,
         params: { state: state_for(email_record.address) },
         headers: { "Host" => @host },
         as: :json

    assert_response :ok

    email_record.reload
    otp_data = email_record.get_otp

    assert_not_nil otp_data

    new_code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s
    verifier = Class.new { include Common::Otp }.new

    assert_not verifier.send(:verify_otp_code, email_record, old_code)[:success]
    assert verifier.send(:verify_otp_code, email_record, new_code)[:success]
  end

  private

  def state_for(email)
    Sign::In::OtpResendState.issue(kind: :email, target: email)
  end
end

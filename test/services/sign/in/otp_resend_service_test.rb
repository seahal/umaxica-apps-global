# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module In
    class OtpResendServiceTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      test "telephone resend keeps otp out of sms title metadata" do
        telephone = ClientTelephone.create!(
          user: clients(:one),
          raw_number: "+819012399991",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        )
        state = OtpResendState.issue(kind: :telephone, target: telephone.number)

        assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
          result = OtpResendService.new(kind: :telephone, state: state).call

          assert_equal :ok, result.status
          assert result.resendable
        end

        job_args = enqueued_jobs.last[:args].first
        body = Outbound::SensitivePayload.decrypt_sms_body(job_args.fetch("encrypted_body"))
        otp_code = body[/\d{6}/]

        assert_equal "Verification code", job_args.fetch("title")
        assert_match(/\A\d{6}\z/, otp_code)
        assert_not_includes job_args.fetch("title"), otp_code
        assert_not_includes job_args.inspect, otp_code
      end
    end
  end
end

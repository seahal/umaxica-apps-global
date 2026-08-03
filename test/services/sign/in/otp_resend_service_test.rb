# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Sign
  module In
    class OtpResendServiceTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      # SMS OTP is not an accepted sign-in proof. Neither a telephone resend
      # state nor a telephone resender may exist, so no SMS can be sent here.
      test "telephone resend state cannot be minted" do
        telephone = ClientTelephone.create!(
          user: clients(:one),
          raw_number: "+819012399991",
          confirm_policy: "1",
          confirm_using_mfa: "1",
        )

        assert_no_enqueued_jobs only: Outbound::SmsDeliveryJob do
          assert_raises(ArgumentError) do
            SignInOtpResendState.issue(kind: :telephone, target: telephone.number)
          end
        end
      end

      test "telephone resender cannot be constructed" do
        state = SignInOtpResendState.issue(kind: :email, target: "resend-guard@example.com")

        assert_no_enqueued_jobs only: Outbound::SmsDeliveryJob do
          assert_raises(ArgumentError) do
            SignInOtpResender.new(kind: :telephone, state: state)
          end
        end
      end

      test "parse returns nil for blank token" do
        assert_nil SignInOtpResendState.parse("")
        assert_nil SignInOtpResendState.parse(nil)
      end

      test "parse returns nil for invalid token signature" do
        assert_nil SignInOtpResendState.parse("invalid-token-signature")
      end
    end
  end
end

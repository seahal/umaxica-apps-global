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

      test "resend rejects an invalid state without enqueuing a delivery" do
        result = nil

        assert_no_enqueued_jobs do
          result = SignInOtpResender.new(kind: :email, state: "invalid-token-signature").call
        end

        assert_equal :bad_request, result.status
        assert_not result.resendable
        assert_equal SignInOtpResender::INVALID_RETRY_AFTER, result.retry_after
      end

      test "unknown email resend records a rate-limit event without revealing account existence" do
        state = SignInOtpResendState.issue(kind: :email, target: "unknown-resend@example.test")
        result = nil

        assert_difference("EmailOccurrence.count", 1) do
          assert_no_enqueued_jobs do
            result = SignInOtpResender.new(kind: :email, state: state).call
          end
        end

        assert_equal :ok, result.status
        assert_predicate result, :resendable
        assert_equal 0, result.retry_after
        assert_match "purpose=in", EmailOccurrence.order(:id).last.memo
      end

      test "known email resend refreshes its OTP and delivers it through the email adapter" do
        email = ClientEmail.create!(
          user: clients(:one),
          address: "known-resend@example.test",
          confirm_policy: "1",
          user_email_status_id: ClientEmailStatus::VERIFIED,
        )
        state = SignInOtpResendState.issue(kind: :email, target: email.address)
        delivery = nil
        adapter = Object.new
        adapter.define_singleton_method(:deliver) { |**arguments| delivery = arguments }

        OtpAdapter.stub(:for, adapter) do
          result = SignInOtpResender.new(kind: :email, state: state).call

          assert_equal :ok, result.status
          assert_predicate result, :resendable
        end

        assert_equal email, delivery.fetch(:record)
        assert_predicate delivery.fetch(:otp_code), :present?
        assert_predicate email.reload.get_otp, :present?
      end
    end
  end
end

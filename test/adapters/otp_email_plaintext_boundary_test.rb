# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/otp_email_records"

# Runs the same OTP email request through both delivery paths and asserts they
# are indistinguishable where it matters. This is the evidence that flipping
# otp_email_notifier_<surface> in production is safe.
class OtpEmailPlaintextBoundaryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include OtpEmailRecords

  OTP_CODE = "246810"

  setup do
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    OtpEmailNotifierRollout::SURFACE_FEATURE_NAMES.each_value { |feature| Flipper.disable(feature) }
  end

  test "no path places the plaintext otp in job arguments" do
    [false, true].each do |rollout_enabled|
      clear_enqueued_jobs
      deliver_app_otp(rollout_enabled: rollout_enabled)

      arguments = enqueued_jobs.map { |job| job[:args].inspect }.join

      assert_not_includes arguments, OTP_CODE, "rollout_enabled=#{rollout_enabled}"
    end
  end

  test "both paths deliver the same rendered otp mail" do
    results =
      [false, true].map do |rollout_enabled|
        ActionMailer::Base.deliveries.clear
        record = nil
        perform_enqueued_jobs { record = deliver_app_otp(rollout_enabled: rollout_enabled) }
        [ActionMailer::Base.deliveries.last, record]
      end

    legacy, notifier = results

    assert_equal legacy.first.subject, notifier.first.subject
    assert_equal legacy.first.from, notifier.first.from
    results.each do |mail, record|
      assert_equal [record.address], mail.to
      assert_match OTP_CODE, mail.html_part.body.decoded
    end
  end

  private

  # Returns the record the OTP was addressed to.
  def deliver_app_otp(rollout_enabled:)
    if rollout_enabled
      Flipper.enable(:otp_email_notifier_app)
    else
      Flipper.disable(:otp_email_notifier_app)
    end

    record = create_otp_email_record(:app, address: "boundary-#{rollout_enabled}@example.com")

    OtpAdapter.for(surface: :app, channel: :email).deliver(record: record, otp_code: OTP_CODE)

    record
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class SignOutNoticeTest < ActiveSupport::TestCase
  fixtures_none!

  class Harness
    include SignOutNotice

    attr_reader :session, :response

    def initialize(session = {})
      @session = session
      @response = Struct.new(:headers).new({})
    end

    def current_sign_out_access_expires_at
      nil
    end
  end

  test "consumes a notice once" do
    harness = Harness.new
    harness.send(:issue_sign_out_notice!)

    notice = harness.send(:consume_sign_out_notice)

    assert notice
    assert_nil harness.session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]
    assert_nil harness.send(:consume_sign_out_notice)
  end

  test "rejects malformed notice payloads" do
    harness = Harness.new(
      SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY => {
        "expires_at" => "not-a-time",
        "remaining_views" => 1,
      },
    )

    assert_nil harness.send(:consume_sign_out_notice)
    assert_nil harness.session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]
  end

  test "rejects expired notices" do
    harness = Harness.new(
      SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY => {
        "expires_at" => 1.minute.ago.iso8601,
        "remaining_views" => 1,
      },
    )

    assert_nil harness.send(:consume_sign_out_notice)
  end
end

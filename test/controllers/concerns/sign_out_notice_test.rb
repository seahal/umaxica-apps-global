# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignOutNoticeTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    class << self
      def helper_method(*)
      end
    end

    include SignOutNotice

    attr_reader :session, :response, :request

    def initialize(session = {})
      @session = session
      @response = Struct.new(:headers).new({})
      @request = Struct.new(:params).new({})
    end

    def current_resource
      nil
    end

    def current_session_public_id
      nil
    end

    def current_sign_out_access_expires_at
      nil
    end
  end

  test "stores and consumes a notice once" do
    harness = Harness.new
    harness.send(:prepare_sign_out_completion_notice!, state: "opaque-state")
    harness.send(:issue_sign_out_notice!)

    notice = harness.send(:consume_sign_out_notice)

    assert notice
    assert_equal "opaque-state", notice[:state]
    assert_nil harness.session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]
    assert_nil harness.send(:consume_sign_out_notice)
  end

  test "rejects expired notices" do
    harness = Harness.new(
      SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY => {
        "expires_at" => 1.minute.ago.iso8601,
        "access_expires_at" => nil,
        "sid" => "sign_out_notice",
      },
    )

    assert_nil harness.send(:consume_sign_out_notice)
    assert_predicate harness.session, :present?
  end

  test "reports completion notice presence when session data is present" do
    harness = Harness.new(SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY => { "expires_at" => 5.minutes.from_now.iso8601 })

    assert_predicate harness, :sign_out_completion_notice_present?
    assert_not_predicate harness, :sign_out_active_context_present?
  end
end

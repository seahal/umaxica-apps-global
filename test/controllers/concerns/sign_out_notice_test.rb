# typed: false
# frozen_string_literal: true

require "test_helper"

class SignOutNoticeTest < ActiveSupport::TestCase
  fixtures_none!

  class Harness
    include SignOutNotice

    attr_reader :session, :response, :request

    def initialize(session = {})
      @session = session
      @response = Struct.new(:headers).new({})
      @request = Struct.new(:params).new({})
    end

    def current_sign_out_access_expires_at
      nil
    end

    def query_parameters
      request.params
    end
  end

  test "consumes a notice once" do
    harness = Harness.new
    harness.send(:issue_sign_out_notice!)
    harness.request.params[SignOutNotice::SIGN_OUT_NOTICE_TOKEN_PARAM] =
      harness.instance_variable_get(:@sign_out_notice_token)

    notice = harness.send(:consume_sign_out_notice)

    assert notice
    assert_nil harness.session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY]
    assert_nil harness.send(:consume_sign_out_notice)
  end

  test "rejects malformed notice payloads" do
    harness = Harness.new
    harness.request.params[SignOutNotice::SIGN_OUT_NOTICE_TOKEN_PARAM] = "malformed"

    assert_nil harness.send(:consume_sign_out_notice)
  end

  test "rejects expired notices" do
    harness = Harness.new
    token = harness.send(:sign_out_notice_verifier).generate(
      {
        "sid" => "sign_out_notice",
        "expires_at" => 1.minute.ago.iso8601,
        "access_expires_at" => nil,
        "jti" => SecureRandom.uuid,
      },
      purpose: SignOutNotice::SIGN_OUT_NOTICE_TOKEN_PURPOSE,
      expires_in: SignOutNotice::SIGN_OUT_NOTICE_TTL,
    )
    harness.request.params[SignOutNotice::SIGN_OUT_NOTICE_TOKEN_PARAM] = token

    assert_nil harness.send(:consume_sign_out_notice)
  end
end

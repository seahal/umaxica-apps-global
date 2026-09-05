# typed: false
# frozen_string_literal: true

require "test_helper"

# The resend endpoint is called from the code-entry page with the opaque state
# that page was rendered with. It answers JSON either way: a state it cannot
# read must not disclose whether the address behind it exists, and a resend
# inside the cooldown must carry the retry window in a header the browser can
# act on.
class Auth::Com::Web::V0::In::Email::OtpsControllerTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    host! @host
  end

  test "a state this surface cannot read is answered without disclosing anything about it" do
    post auth_com_web_v0_in_email_otp_url(ri: "jp"),
         params: { state: "not-a-state" },
         headers: { "Host" => @host }

    assert_response :bad_request
    body = response.parsed_body

    assert_includes body.keys, "resendable"
    assert_includes body.keys, "retry_after"
  end

  test "a resend inside the cooldown carries the retry window in a header" do
    too_soon = SignInOtpResender::Response.new(
      status: :too_many_requests, resendable: false, retry_after: 30,
    )

    resender = Struct.new(:response_value) do
      def call = response_value
    end.new(too_soon)

    SignInOtpResender.stub(:new, ->(**) { resender }) do
      post auth_com_web_v0_in_email_otp_url(ri: "jp"),
           params: { state: "any-state" },
           headers: { "Host" => @host }
    end

    assert_equal "30", response.headers["Retry-After"]
    assert_not response.parsed_body.fetch("resendable")
  end
end

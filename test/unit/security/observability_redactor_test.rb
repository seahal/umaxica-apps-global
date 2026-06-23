# frozen_string_literal: true

require "test_helper"

class ObservabilityRedactorTest < ActiveSupport::TestCase
  test "scrubs nested sensitive values and urls" do
    value = ObservabilityRedactor.scrub(
      {
        email: "person@example.com",
        token: "secret-token",
        nested: [
          { cookie: "a=b", original_url: "https://example.com/path?code=abc&state=xyz" },
          { url: "https://example.com/inside?rt=token" },
        ],
      },
    )

    assert_equal "[FILTERED]", value[:email]
    assert_equal "[FILTERED]", value[:token]
    assert_equal "[FILTERED]", value[:nested][0][:cookie]
    assert_equal "https://example.com/path", value[:nested][0][:original_url]
    assert_equal "https://example.com/inside", value[:nested][1][:url]
  end

  test "scrubs query-bearing strings" do
    assert_equal "https://example.com/path", ObservabilityRedactor.scrub("https://example.com/path?jwt=abc")
  end

  test "scrub_url returns REDACTED for an unparseable URI" do
    assert_equal ObservabilityRedactor::REDACTED, ObservabilityRedactor.scrub_url("https://[invalid")

    assert_equal(
      { "original_url" => ObservabilityRedactor::REDACTED },
      ObservabilityRedactor.scrub("original_url" => "https://[invalid-bracket"),
    )
  end

  test "scrub leaves non-HTTP strings starting with https scheme prefix unchanged" do
    assert_equal "not a url", ObservabilityRedactor.scrub("not a url")
  end
end

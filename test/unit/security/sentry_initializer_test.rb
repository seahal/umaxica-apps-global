# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SentryInitializerTest < ActiveSupport::TestCase
  test "configures pii off and scrubs sensitive event data" do
    assert_not Sentry.configuration.send_default_pii
    assert Sentry.configuration.before_send
  end

  test "before_send scrubs request fields and nested event data" do
    request = Struct.new(:url, :query_string, :env, :data, :headers, :cookies).new(
      "https://example.com/path?token=secret",
      "token=secret",
      {
        "HTTP_AUTHORIZATION" => "Bearer secret",
        "HTTP_COOKIE" => "session=secret",
      },
      {
        params: [{ access_token: "secret" }],
      },
      {
        authorization: "Bearer secret",
        cookie: "session=secret",
      },
      {
        session_id: "secret",
      },
    )
    breadcrumb = Struct.new(:message, :data).new("https://example.com/path?code=abc", { token: "secret" })
    event = Struct.new(:request, :extra, :tags, :user, :breadcrumbs).new(
      request,
      { original_url: "https://example.com/path?code=abc" },
      { token: "secret" },
      { email: "person@example.com" },
      [breadcrumb],
    )

    scrubbed = Sentry.configuration.before_send.call(event, nil)

    assert_equal "https://example.com/path", scrubbed.request.url
    assert_equal "[FILTERED]", scrubbed.request.query_string
    assert_equal "[FILTERED]", scrubbed.request.env["HTTP_AUTHORIZATION"]
    assert_equal "[FILTERED]", scrubbed.request.headers[:authorization]
    assert_equal "[FILTERED]", scrubbed.request.cookies[:session_id]
    assert_equal "[FILTERED]", scrubbed.request.data.dig(:params, 0, :access_token)
    assert_equal "https://example.com/path", scrubbed.extra[:original_url]
    assert_equal "[FILTERED]", scrubbed.tags[:token]
    assert_equal "[FILTERED]", scrubbed.user[:email]
    assert_equal "https://example.com/path", scrubbed.breadcrumbs.first.message
    assert_equal "[FILTERED]", scrubbed.breadcrumbs.first.data[:token]
  end
end

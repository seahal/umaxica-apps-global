# typed: false
# frozen_string_literal: true

require "test_helper"

module OutboundHttp
  class ConnectionTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    HTTPS_URL = "https://example.test/keys"

    test "applies the requested timeouts to the connection" do
      connection = Connection.build(url: HTTPS_URL, open_timeout: 2, read_timeout: 5, require_https: true)

      assert_equal 2, connection.options.open_timeout
      assert_equal 5, connection.options.timeout
    end

    # The timeouts are the reason this class exists: four call sites previously
    # ran on the stdlib default and held a request thread for a minute. A caller
    # that omits one has to fail here rather than inherit a transport default.
    test "refuses to build a connection without timeouts" do
      assert_raises(ArgumentError) { Connection.build(url: HTTPS_URL, read_timeout: 5, require_https: true) }
      assert_raises(ArgumentError) { Connection.build(url: HTTPS_URL, open_timeout: 2, require_https: true) }
    end

    test "requires the caller to state its transport security policy" do
      assert_raises(ArgumentError) { Connection.build(url: HTTPS_URL, open_timeout: 2, read_timeout: 5) }
    end

    test "leaves the write timeout unset unless the caller pins one" do
      connection = Connection.build(url: HTTPS_URL, open_timeout: 2, read_timeout: 5, require_https: true)

      assert_nil connection.options.write_timeout

      pinned = Connection.build(
        url: HTTPS_URL, open_timeout: 3, read_timeout: 3, write_timeout: 3, require_https: true,
      )

      assert_equal 3, pinned.options.write_timeout
    end

    test "rejects a plaintext endpoint when the caller requires HTTPS" do
      error =
        assert_raises(Connection::InsecureEndpointError) do
          Connection.build(url: "http://example.test/keys", open_timeout: 2, read_timeout: 5, require_https: true)
        end

      assert_match(/HTTPS/, error.message)
    end

    # OidcBackchannelLogoutDeliveryJob posts to a scheme chosen by the client
    # registration, not by the job, so plaintext has to remain expressible.
    test "permits a plaintext endpoint when the caller opts out" do
      connection = Connection.build(
        url: "http://example.test/logout", open_timeout: 2, read_timeout: 5, require_https: false,
      )

      assert_equal "http", connection.url_prefix.scheme
    end

    test "accepts a URI as well as a string" do
      connection = Connection.build(
        url: URI("https://example.test/keys"), open_timeout: 2, read_timeout: 5, require_https: true,
      )

      assert_equal "example.test", connection.url_prefix.host
    end

    # Following a redirect would let an allowlisted destination hand the request
    # to an unlisted one, which is the SSRF the back-channel logout allowlist
    # exists to prevent.
    test "does not install redirect-following middleware" do
      connection = Connection.build(url: HTTPS_URL, open_timeout: 2, read_timeout: 5, require_https: true)

      assert_empty connection.builder.handlers.map(&:name).grep(/FollowRedirects/)
    end

    test "surfaces a redirect as a response instead of chasing it" do
      stubs =
        Faraday::Adapter::Test::Stubs.new do |stub|
          stub.get("https://example.test/keys") { [302, { "Location" => "https://elsewhere.test/keys" }, ""] }
        end

      response =
        stub_outbound_http(stubs) do
          Connection.build(url: HTTPS_URL, open_timeout: 2, read_timeout: 5, require_https: true)
            .get("https://example.test/keys")
        end

      assert_equal 302, response.status
      assert_not_predicate response, :success?
      stubs.verify_stubbed_calls
    end

    # Faraday.default_adapter is shared with the OmniAuth, OAuth2, and
    # openid_connect chain; this class must not reassign it as a side effect.
    test "pins its own adapter without touching the Faraday global" do
      assert_equal :net_http, Connection.default_adapter
      assert_equal :net_http, Faraday.default_adapter
    end
  end
end

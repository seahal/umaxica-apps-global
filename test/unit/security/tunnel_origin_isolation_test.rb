# typed: false
# frozen_string_literal: true

require "test_helper"
require "yaml"

module Security
  # ActionDispatch::RemoteIp does not gate X-Forwarded-For trust on whether the
  # immediate connecting peer is a trusted proxy - it only strips proxy-hop IPs
  # from within the header's own value (see
  # vendor/bundle/.../action_dispatch/middleware/remote_ip.rb). A request that
  # reaches Rails directly, bypassing cloudflared, can therefore set an arbitrary
  # X-Forwarded-For (or, if ever configured, CF-Connecting-IP) value and have it
  # trusted regardless of `trusted_proxies`. The actual control against spoofing is
  # network isolation: `core` must never be reachable from off the host except
  # through the tunnel. See docs/architecture/cloudflare-request-paths.md.
  #
  # The developer's own browser needs `core`, so `.devcontainer/compose.yaml` publishes it -
  # but every entry must carry an explicit loopback bind address. A bare `3000:3000` makes
  # Podman bind 0.0.0.0, putting Rails on the LAN, Wi-Fi, and Tailscale interfaces.
  class TunnelOriginIsolationTest < ActiveSupport::TestCase
    LOOPBACK_PUBLICATION = /\A(?:127\.0\.0\.1|\[::1\]):\d+:\d+(?:\/\w+)?\z/

    test "the compose definition publishes core only on loopback" do
      compose = YAML.unsafe_load_file(Rails.root.join(".devcontainer/compose.yaml"))
      core_service = compose.fetch("services").fetch("core")

    test "every compose definition publishes Rails only on loopback" do
      RAILS_SERVICES.each do |compose_file, service|
        compose = YAML.unsafe_load_file(Rails.root.join(compose_file))
        definition = compose.fetch("services").fetch(service)

        assert_predicate Array(definition["ports"]), :any?,
                         "#{compose_file}: #{service} publishes nothing, so this guard is vacuous"

        Array(definition["ports"]).each do |publication|
          assert_match LOOPBACK_PUBLICATION, publication,
                       "#{compose_file}: #{service} publishes #{publication.inspect} without an " \
                       "explicit loopback bind address. Podman would bind 0.0.0.0, letting any " \
                       "host on the network reach Rails directly, bypassing cloudflared, and " \
                       "forge X-Forwarded-For/CF-Connecting-IP unimpeded."
        end
      end
    end

    test "X-Forwarded-For from an untrusted direct peer is still honored by RemoteIp (documents the real risk)" do
      env = Rack::MockRequest.env_for(
        "http://example.test/health",
        "REMOTE_ADDR" => "198.51.100.7", # RFC 5737 TEST-NET-2: simulates a direct, non-proxy peer
        "HTTP_X_FORWARDED_FOR" => "203.0.113.99", # RFC 5737 TEST-NET-3: attacker-declared IP
      )
      middleware = ActionDispatch::RemoteIp.new(->(_e) { [200, {}, [""]] }, true, [])
      middleware.call(env)
      request = ActionDispatch::Request.new(env)

      assert_equal "203.0.113.99", request.remote_ip,
                   "This assertion documents a real property of ActionDispatch::RemoteIp, not a " \
                   "desired outcome: trusted_proxies does not stop a direct, untrusted peer from " \
                   "forging X-Forwarded-For. If this ever starts failing, RemoteIp's behavior has " \
                   "changed upstream and the network-isolation reasoning in " \
                   "docs/architecture/cloudflare-request-paths.md must be re-verified."
    end
  end
end

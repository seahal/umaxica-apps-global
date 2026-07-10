# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CommonRedirectTest < ActiveSupport::TestCase
  test "private helper methods are not public on including controller" do
    # Define a test controller that includes the concern
    test_controller =
      Class.new(ApplicationController) do
        include CommonRedirect
      end

    controller = test_controller.new

    # These methods should be private, not public
    assert_includes controller.private_methods, :safe_internal_path
    assert_not controller.public_methods.include?(:safe_internal_path)

    assert_includes controller.private_methods, :safe_redirect_to
    assert_not controller.public_methods.include?(:safe_redirect_to)

    assert_includes controller.private_methods, :safe_redirect_back_or_to
    assert_not controller.public_methods.include?(:safe_redirect_back_or_to)

    assert_includes controller.private_methods, :generate_redirect_url
    assert_not controller.public_methods.include?(:generate_redirect_url)

    assert_includes controller.private_methods, :jump_to_generated_url
    assert_not controller.public_methods.include?(:jump_to_generated_url)

    assert_includes controller.private_methods, :redirect_to_jump_rt
    assert_not controller.public_methods.include?(:redirect_to_jump_rt)
  end

  test "allowed_hosts is public on including controller" do
    test_controller =
      Class.new(ApplicationController) do
        include CommonRedirect
      end

    controller = test_controller.new

    # allowed_hosts should remain public (for diagnostics/auditing)
    assert_respond_to controller, :allowed_hosts
    assert_not controller.private_methods.include?(:allowed_hosts)
  end

  test "normalize_host returns nil for blank values" do
    assert_nil CommonRedirect.normalize_host(nil)
    assert_nil CommonRedirect.normalize_host("")
    assert_nil CommonRedirect.normalize_host("   ")
  end

  test "normalize_host extracts host from URL" do
    assert_equal "example.com", CommonRedirect.normalize_host("https://example.com/path")
    assert_equal "example.com", CommonRedirect.normalize_host("http://example.com")
    assert_equal "example.com", CommonRedirect.normalize_host("example.com/path")
  end

  test "normalize_host handles invalid URIs" do
    assert_equal "not a url", CommonRedirect.normalize_host("not a url")
  end

  test "normalize_host downcases host" do
    assert_equal "example.com", CommonRedirect.normalize_host("HTTPS://EXAMPLE.COM")
  end

  # --- Open-redirect regression guards -------------------------------------
  #
  # safe_internal_path / safe_return_path are the security boundary that keeps
  # user-supplied return targets from redirecting off-site. These tests pin the
  # rejection contract so a future refactor cannot silently widen it.

  def redirect_helper
    @redirect_helper ||=
      Class.new(ApplicationController) { include CommonRedirect }.new
  end

  test "safe_internal_path rejects blank and control-character input" do
    assert_nil redirect_helper.send(:safe_internal_path, nil)
    assert_nil redirect_helper.send(:safe_internal_path, "")
    assert_nil redirect_helper.send(:safe_internal_path, "/dash\nboard")
    assert_nil redirect_helper.send(:safe_internal_path, "/dash\tboard")
    assert_nil redirect_helper.send(:safe_internal_path, :dashboard)
  end

  test "safe_internal_path rejects absolute, scheme, host, and userinfo targets" do
    assert_nil redirect_helper.send(:safe_internal_path, "https://evil.example/path")
    assert_nil redirect_helper.send(:safe_internal_path, "//evil.example/path")
    assert_nil redirect_helper.send(:safe_internal_path, "http://user:pass@evil.example/")
    assert_nil redirect_helper.send(:safe_internal_path, "javascript:alert(1)")
    assert_nil redirect_helper.send(:safe_internal_path, "relative/path")
  end

  test "safe_internal_path rejects fragments and ambiguous encoded path bytes" do
    assert_nil redirect_helper.send(:safe_internal_path, "/#fragment")
    assert_nil redirect_helper.send(:safe_internal_path, "/dashboard#fragment")
    assert_nil redirect_helper.send(:safe_internal_path, "/dash\\board")
    assert_nil redirect_helper.send(:safe_internal_path, "/%2F%2Fevil.example")
    assert_nil redirect_helper.send(:safe_internal_path, "/%5Cevil")
    assert_nil redirect_helper.send(:safe_internal_path, "/%00")
    assert_nil redirect_helper.send(:safe_internal_path, "/%0d%0aLocation:%20https://evil.example")
  end

  test "safe_internal_path accepts clean internal paths and preserves query" do
    assert_equal "/dashboard", redirect_helper.send(:safe_internal_path, "/dashboard")
    assert_equal "/dashboard?a=1&b=2", redirect_helper.send(:safe_internal_path, "/dashboard?a=1&b=2")
  end

  test "safe_return_path rejects external hosts when no host is allowed" do
    assert_nil redirect_helper.send(:safe_return_path, :dashboard)
    assert_nil redirect_helper.send(:safe_return_path, "https://evil.example/path")
    assert_nil redirect_helper.send(:safe_return_path, "//evil.example/path")
  end

  test "safe_return_path rejects non-http schemes and userinfo even for allowed hosts" do
    allowed = ["trusted.example.com"]

    assert_nil redirect_helper.send(:safe_return_path, "ftp://trusted.example.com/x", allowed_hosts: allowed)
    assert_nil redirect_helper.send(:safe_return_path, "javascript:alert(1)", allowed_hosts: allowed)
    assert_nil redirect_helper.send(:safe_return_path, "https://u:p@trusted.example.com/x", allowed_hosts: allowed)
  end

  test "safe_return_path is path target only and ignores legacy allowed hosts" do
    allowed = ["trusted.example.com"]

    assert_nil redirect_helper.send(
      :safe_return_path, "https://trusted.example.com/welcome?ref=1",
      allowed_hosts: allowed,
    )
  end

  test "generate_redirect_url drops off-site targets and round-trips internal ones" do
    assert_nil redirect_helper.send(:generate_redirect_url, "https://evil.example/x")

    encoded = redirect_helper.send(:generate_redirect_url, "/safe?a=1")

    assert_not_nil encoded
    assert_equal "/safe?a=1", redirect_helper.send(:safe_return_path, Base64.urlsafe_decode64(encoded))
  end

  test "redirect_to_jump_rt redirects through dedicated jump gateway" do
    controller = redirect_helper
    redirects = []
    token = "#{"a" * 22}.#{"b" * 22}.#{"c" * 22}"
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }

    with_env("PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net") do
      controller.send(:redirect_to_jump_rt, token)
    end

    assert_equal [["https://jump.umaxica.net/?rt=#{token}", { allow_other_host: true }]], redirects
  end

  test "redirect_to_jump_rt rejects malformed token" do
    controller = redirect_helper
    renders = []
    controller.define_singleton_method(:render) { |**kwargs| renders << kwargs }
    controller.define_singleton_method(:request) { Struct.new(:request_id).new("request-id") }

    controller.send(:redirect_to_jump_rt, "not-a-jwt")

    assert_equal :unprocessable_content, renders.first.fetch(:status)
  end

  test "redirect_to_jump_url issues token using controller namespace" do
    controller =
      Class.new(ApplicationController) do
        include CommonRedirect

        def self.name = "Sign::App::HarnessController"
      end.new
    redirects = []
    private_key = OpenSSL::PKey::EC.generate("secp384r1")
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }

    with_env(
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a",
      "PRIVATE_AUTH_SERVICE_URL" => "log.umaxica.app",
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
    ) do
      JumpRtKeyring.stub(:private_key, private_key) do
        controller.send(:redirect_to_jump_url, "https://www.umaxica.app/dashboard")
      end
    end

    location = redirects.first.first
    uri = URI.parse(location)
    token = Rack::Utils.parse_query(uri.query).fetch("rt")
    payload, header = JWT.decode(token, nil, false)
    parts = token.split(".")

    assert_equal "https", uri.scheme
    assert_equal "jump.umaxica.net", uri.host
    assert_operator token.bytesize, :>, 64
    assert_equal 3, parts.size
    assert parts.all?(&:present?)
    assert parts.all? { |part| part.match?(/\A[A-Za-z0-9_-]+\z/) }
    assert_no_match(/[=+\/]/, token)
    assert_equal "JWT", header["typ"]
    assert_equal "ES384", header["alg"]
    assert_equal JitSecurityJwtRegistry.surface("SIGN_APP").current_kid, header["kid"]
    assert_equal "https://log.umaxica.app", payload["iss"]
    assert_equal "reuse", payload["rpl"]
    assert_equal "https://www.umaxica.app/dashboard", payload["url"]
    assert_equal({ allow_other_host: true }, redirects.first.last)
  end

  test "redirect_to_jump_url logs only safe token metadata" do
    controller =
      Class.new(ApplicationController) do
        include CommonRedirect

        def self.name = "Sign::App::HarnessController"
      end.new
    redirects = []
    logs = []
    private_key = OpenSSL::PKey::EC.generate("secp384r1")
    logger = Struct.new(:logs) do
      def info(message)
        logs << message
      end
    end.new(logs)
    request = Struct.new(:request_id, :referer, :user_agent, :remote_ip, :headers).new(
      "request-id",
      "https://www.umaxica.app/source?private=1",
      "Test Browser",
      "203.0.113.10",
      {
        "CF-Connecting-IP" => "198.51.100.20",
        "CF-Ray" => "ray-test",
        "CF-ASN" => "64500",
        "CF-IPCountry" => "JP",
      },
    )
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }
    controller.define_singleton_method(:request) { request }

    with_env(
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a",
      "PRIVATE_AUTH_SERVICE_URL" => "log.umaxica.app",
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
    ) do
      JumpRtKeyring.stub(:private_key, private_key) do
        Rails.stub(:logger, logger) do
          controller.send(:redirect_to_jump_url, "https://www.umaxica.app/dashboard?secret_credential=hidden")
        end
      end
    end

    token = Rack::Utils.parse_query(URI.parse(redirects.first.first).query).fetch("rt")
    parsed = JSON.parse(logs.find { |entry| entry.include?("jump_rt.issued") })
    data = parsed.fetch("data")

    assert_equal "jump_rt.issued", parsed.fetch("event")
    assert_equal token.bytesize, data.fetch("rt_length")
    assert_equal 3, data.fetch("rt_parts")
    assert_equal Digest::SHA256.hexdigest(token)[0, 12], data.fetch("rt_digest12")
    assert_equal Digest::SHA256.hexdigest("https://www.umaxica.app/source?private=1")[0, 12],
                 data.fetch("referer_digest12")
    assert_equal Digest::SHA256.hexdigest("Test Browser")[0, 12], data.fetch("user_agent_digest12")
    assert_equal Digest::SHA256.hexdigest("203.0.113.10")[0, 12], data.fetch("remote_ip_digest12")
    assert_equal Digest::SHA256.hexdigest("198.51.100.20")[0, 12], data.fetch("cf_connecting_ip_digest12")
    assert_equal "ray-test", data.fetch("cf_ray")
    assert_equal "64500", data.fetch("cf_asn")
    assert_equal "JP", data.fetch("cf_ipcountry")
    assert_not_includes logs.join, token
    assert_not_includes logs.join, "secret_credential=hidden"
    assert_not_includes logs.join, "private=1"
    assert_not_includes logs.join, "203.0.113.10"
    assert_not_includes logs.join, "198.51.100.20"
  end

  test "redirect_to_external_jump_url validates then redirects through jump as external destination" do
    controller =
      Class.new(ApplicationController) do
        include CommonRedirect

        def self.name = "Sign::App::HarnessController"
      end.new
    redirects = []
    private_key = OpenSSL::PKey::EC.generate("secp384r1")
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }

    with_env(
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a",
      "PRIVATE_AUTH_SERVICE_URL" => "log.umaxica.app",
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
    ) do
      JumpRtKeyring.stub(:private_key, private_key) do
        controller.send(
          :redirect_to_external_jump_url,
          "https://rp.example/callback?ok=1",
          allowed_urls: ["https://rp.example/callback"],
        )
      end
    end

    location = redirects.first.first
    uri = URI.parse(location)
    token = Rack::Utils.parse_query(uri.query).fetch("rt")
    payload, = JWT.decode(token, nil, false)

    assert_equal "https://jump.umaxica.net", "#{uri.scheme}://#{uri.host}"
    assert_equal "external", payload["dst"]
    assert_equal "reuse", payload["rpl"]
    assert_equal "https://rp.example/callback?ok=1", payload["url"]
    assert_equal({ allow_other_host: true }, redirects.first.last)
  end

  test "redirect_to_external_jump validates registry target then redirects through jump as external destination" do
    controller =
      Class.new(ApplicationController) do
        include CommonRedirect

        def self.name = "Sign::App::HarnessController"
      end.new
    redirects = []
    private_key = OpenSSL::PKey::EC.generate("secp384r1")
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }

    with_env(
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a",
      "PRIVATE_AUTH_SERVICE_URL" => "log.umaxica.app",
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
      "RP_APP_URL" => "https://rp.example",
    ) do
      JumpRtKeyring.stub(:private_key, private_key) do
        controller.send(:redirect_to_external_jump, :rp_app, path: "/signed-out", query: { ok: "1", rt: "drop.me" })
      end
    end

    location = redirects.first.first
    uri = URI.parse(location)
    token = Rack::Utils.parse_query(uri.query).fetch("rt")
    payload, = JWT.decode(token, nil, false)

    assert_equal "https://jump.umaxica.net", "#{uri.scheme}://#{uri.host}"
    assert_equal "external", payload["dst"]
    assert_equal "reuse", payload["rpl"]
    assert_equal "https://rp.example/signed-out?ok=1", payload["url"]
    assert_equal({ allow_other_host: true }, redirects.first.last)
  end

  test "redirect_to_jump_url can fall back to same-host internal path when token cannot be issued" do
    controller = redirect_helper
    redirects = []
    request = Struct.new(:host, :host_with_port, :request_id).new("log.umaxica.app", "log.umaxica.app", "request-id")
    controller.define_singleton_method(:request) { request }
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }

    with_env(
      "JWT_SIGN_APP_ACTIVE_KID" => nil,
      "PRIVATE_AUTH_SERVICE_URL" => "log.umaxica.app",
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
    ) do
      controller.send(
        :redirect_to_jump_url,
        "https://log.umaxica.app/sign/in?ri=jp&pt=signed",
        fallback_internal: true,
        alert: "login required",
      )
    end

    assert_equal(
      [["/sign/in?ri=jp&pt=signed", { allow_other_host: false, alert: "login required" }]],
      redirects,
    )
  end

  test "redirect_to_jump_url can fall back to same-host internal path when gateway URL is invalid" do
    controller = redirect_helper
    redirects = []
    request = Struct.new(:host, :host_with_port, :request_id).new("log.umaxica.app", "log.umaxica.app", "request-id")
    controller.define_singleton_method(:request) { request }
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }

    with_env("PUBLIC_JUMP_GATEWAY_URL" => "http://jump.example") do
      JumpRtIssuer.stub(:call, "aaa.bbb.ccc") do
        controller.send(
          :redirect_to_jump_url,
          "https://log.umaxica.app/sign/in?ri=jp&pt=signed",
          fallback_internal: true,
          alert: "login required",
        )
      end
    end

    assert_equal(
      [["/sign/in?ri=jp&pt=signed", { allow_other_host: false, alert: "login required" }]],
      redirects,
    )
  end

  test "redirect_to_jump_url emits jump_rt.fallback_internal warning when token cannot be issued" do
    controller =
      Class.new(ApplicationController) do
        include CommonRedirect

        def self.name = "Sign::App::HarnessController"
      end.new
    redirects = []
    logs = []
    logger = Struct.new(:logs) do
      def info(message) = logs << message

      def warn(message) = logs << message
    end.new(logs)
    request = Struct.new(:host, :host_with_port, :request_id).new("log.umaxica.app", "log.umaxica.app", "request-id")
    controller.define_singleton_method(:request) { request }
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }

    with_env(
      "PRIVATE_AUTH_SERVICE_URL" => "log.umaxica.app",
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
    ) do
      JumpRtIssuer.stub(:call, nil) do
        Rails.stub(:logger, logger) do
          controller.send(
            :redirect_to_jump_url,
            "https://log.umaxica.app/sign/in?secret_credential=hidden",
            fallback_internal: true,
          )
        end
      end
    end

    entry = logs.find { |line| line.include?("jump_rt.fallback_internal") }
    parsed = JSON.parse(entry)
    data = parsed.fetch("data")

    assert_equal "jump_rt.fallback_internal", parsed.fetch("event")
    assert_equal "issuance_failed", data.fetch("reason")
    assert_equal "SIGN_APP", data.fetch("namespace")
    assert_equal Digest::SHA256.hexdigest("https://log.umaxica.app/sign/in?secret_credential=hidden")[0, 12],
                 data.fetch("target_url_digest")
    assert_not_includes logs.join, "secret_credential=hidden"
  end

  test "redirect_to_jump_url emits jump_rt.fallback_internal warning when gateway url is invalid" do
    controller =
      Class.new(ApplicationController) do
        include CommonRedirect

        def self.name = "Sign::App::HarnessController"
      end.new
    redirects = []
    logs = []
    logger = Struct.new(:logs) do
      def info(message) = logs << message

      def warn(message) = logs << message
    end.new(logs)
    request = Struct.new(:host, :host_with_port, :request_id).new("log.umaxica.app", "log.umaxica.app", "request-id")
    controller.define_singleton_method(:request) { request }
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }
    fake_token = "#{"a" * 22}.#{"b" * 22}.#{"c" * 22}"

    with_env("PUBLIC_JUMP_GATEWAY_URL" => "http://jump.example") do
      Rails.stub(:logger, logger) do
        JumpRtIssuer.stub(:call, fake_token) do
          controller.send(
            :redirect_to_jump_url,
            "https://log.umaxica.app/sign/in",
            fallback_internal: true,
          )
        end
      end
    end

    entry = logs.find { |line| line.include?("jump_rt.fallback_internal") }
    parsed = JSON.parse(entry)
    data = parsed.fetch("data")

    assert_equal "gateway_url_failed", data.fetch("reason")
    assert_equal "invalid_uri", data.fetch("gateway_failure")
  end

  test "redirect_to_jump_url renders invalid request when token cannot be issued without fallback" do
    controller = redirect_helper
    renders = []
    redirects = []
    controller.define_singleton_method(:request) { Struct.new(:request_id).new("request-id") }
    controller.define_singleton_method(:render) { |**kwargs| renders << kwargs }
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }

    with_env(
      "JWT_SIGN_APP_ACTIVE_KID" => nil,
      "PRIVATE_AUTH_SERVICE_URL" => "log.umaxica.app",
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
    ) do
      controller.send(:redirect_to_jump_url, "https://www.umaxica.app/dashboard")
    end

    assert_empty redirects
    assert_equal :unprocessable_content, renders.first.fetch(:status)
  end

  test "redirect_to_jump_url does not redirect to jump when gateway rejects issued token" do
    controller = redirect_helper
    renders = []
    redirects = []
    controller.define_singleton_method(:request) { Struct.new(:request_id).new("request-id") }
    controller.define_singleton_method(:render) { |**kwargs| renders << kwargs }
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }

    JumpRtIssuer.stub(:call, "xxx") do
      controller.send(:redirect_to_jump_url, "https://www.umaxica.app/dashboard")
    end

    assert_empty redirects
    assert_equal :unprocessable_content, renders.first.fetch(:status)
  end

  def with_env(values)
    previous = values.transform_values { |_value| nil }
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end

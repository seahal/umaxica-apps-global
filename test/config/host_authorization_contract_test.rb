# typed: false
# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"

class HostAuthorizationContractTest < Minitest::Test
  PRIVATE_ORIGIN_HOSTS = %w(
    auth.app.localhost:3000
    auth.com.localhost:3000
    auth.org.localhost:3000
    base.app.localhost:3000
    base.com.localhost:3000
    base.org.localhost:3000
    base.net.localhost:3000
    base.dev.localhost:3000
  ).freeze

  def test_effective_development_middleware_accepts_private_origins_and_rejects_an_unknown_host
    runner = <<~'RUBY'
      require "json"
      require "rack/mock"

      endpoint = ->(_env) { [200, { "content-type" => "text/plain" }, ["accepted"]] }
      middleware = ActionDispatch::HostAuthorization.new(
        endpoint,
        Rails.application.config.hosts,
        **Rails.application.config.host_authorization,
      )
      hosts = JSON.parse(ENV.fetch("HOST_AUTHORIZATION_TEST_HOSTS"))
      statuses = hosts.to_h do |host|
        response = Rack::MockRequest.new(middleware).get("/", "HTTP_HOST" => host)
        [host, response.status]
      end
      puts JSON.generate(statuses)
    RUBY
    tailscale_serve_host = "umaxica-global-core.example-tailnet.ts.net"
    hosts = PRIVATE_ORIGIN_HOSTS + [tailscale_serve_host, "evil.example.com"]
    stdout, stderr, status = Open3.capture3(
      {
        "RAILS_ENV" => "development",
        "HOST_AUTHORIZATION_TEST_HOSTS" => JSON.generate(hosts),
        "PRIVATE_AUTH_CORPORATE_URL" => "http://configured-auth.com.localhost:3000",
        "PRIVATE_AUTH_STAFF_URL" => "http://configured-auth.org.localhost:3000",
        "PRIVATE_BASE_NETWORK_URL" => "http://configured-base.net.localhost:3000",
        "PRIVATE_BASE_DEVELOPER_URL" => "http://configured-base.dev.localhost:3000",
        "TAILSCALE_SERVE_HOST" => tailscale_serve_host,
      },
      "bin/rails",
      "runner",
      runner,
    )

    assert_predicate status, :success?, stderr

    statuses = JSON.parse(stdout.lines.last)

    PRIVATE_ORIGIN_HOSTS.each do |host|
      assert_equal 200, statuses.fetch(host), "expected Host Authorization to accept #{host}"
    end
    assert_equal 200, statuses.fetch(tailscale_serve_host)
    assert_equal 403, statuses.fetch("evil.example.com")
  end

  def test_tailscale_serve_host_is_optional_but_must_be_a_bare_ts_net_hostname
    development_config = File.read(File.expand_path("../../config/environments/development.rb", __dir__))

    assert_match(/ENV\["TAILSCALE_SERVE_HOST"\]/, development_config)
    assert_match(/must be a bare \.ts\.net hostname/, development_config)
    # Plain Minitest does not provide Rails' assert_no_match assertion.
    # rubocop:disable Rails/RefuteMethods
    refute_match(/config\.hosts\s*<<\s*\/.*ts\\\.net/, development_config)
    # rubocop:enable Rails/RefuteMethods
  end

  def test_host_configuration_does_not_contain_a_catastrophic_broad_bypass
    development_config = File.read(File.expand_path("../../config/environments/development.rb", __dir__))
    production_config = File.read(File.expand_path("../../config/environments/production.rb", __dir__))

    # Plain Minitest does not provide Rails' assert_no_match assertion.
    # rubocop:disable Rails/RefuteMethods
    refute_match(/config\.hosts\.clear/, development_config)
    refute_match(/config\.hosts\.clear/, production_config)
    refute_match(/config\.hosts\s*<<\s*\/.+\//, development_config)
    refute_match(/config\.hosts\s*<<\s*\/.+\//, production_config)
    # rubocop:enable Rails/RefuteMethods
  end
end

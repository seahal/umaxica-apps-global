# typed: false
# frozen_string_literal: true

require "test_helper"
require "ostruct"

class SignRouteHostTest < ActionDispatch::IntegrationTest
  test "sign app routes match SIGN_SERVICE_URL" do
    with_boot_config(sign_service_host: "sign.app.example.test") do
      host!("sign.app.example.test")

      get("http://sign.app.example.test/")

      assert_not_equal 404, response.status
    end
  ensure
    Rails.application.reload_routes!
  end

  test "sign com named root route points at sign/com/roots#index" do
    with_boot_config(sign_corporate_host: "sign.com.example.test") do
      route = Rails.application.routes.named_routes[:sign_com_root]

      assert_equal "/", route.path.spec.to_s
      assert_equal "sign/com/roots", route.defaults[:controller]
      assert_equal "index", route.defaults[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  test "sign org routes match SIGN_STAFF_URL" do
    with_boot_config(sign_staff_host: "sign.org.example.test") do
      host!("sign.org.example.test")

      get("http://sign.org.example.test/")

      assert_not_equal 404, response.status
    end
  ensure
    Rails.application.reload_routes!
  end

  private

  class BootConfig
    def initialize(hosts)
      @hosts = hosts
    end

    def fetch(key)
      return @hosts if key == :hosts

      raise KeyError, key.to_s
    end
  end

  def with_boot_config(sign_service_host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
                       sign_corporate_host: ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"),
                       sign_staff_host: ENV.fetch("SIGN_STAFF_URL", "id.org.localhost"))
    hosts = OpenStruct.new(
      acme_service: OpenStruct.new(host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")),
      acme_corporate: OpenStruct.new(host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")),
      acme_staff: OpenStruct.new(host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost")),
      sign_service: OpenStruct.new(host: sign_service_host),
      sign_corporate: OpenStruct.new(host: sign_corporate_host),
      sign_staff: OpenStruct.new(host: sign_staff_host),
      core_service: OpenStruct.new(host: ENV.fetch("CORE_SERVICE_URL", "core-jp.umaxica.app")),
      core_corporate: OpenStruct.new(host: ENV.fetch("CORE_CORPORATE_URL", "core-jp.umaxica.com")),
      core_staff: OpenStruct.new(host: ENV.fetch("CORE_STAFF_URL", "core-jp.umaxica.org")),
      base_service: OpenStruct.new(host: ENV.fetch("BASE_SERVICE_URL", "www-jp.umaxica.app")),
      base_corporate: OpenStruct.new(host: ENV.fetch("BASE_CORPORATE_URL", "www-jp.umaxica.com")),
      base_staff: OpenStruct.new(host: ENV.fetch("BASE_STAFF_URL", "www-jp.umaxica.org")),
      palm_service: OpenStruct.new(host: ENV.fetch("PALM_SERVICE_URL", "palm-jp.umaxica.app")),
      palm_corporate: OpenStruct.new(host: ENV.fetch("PALM_CORPORATE_URL", "palm-jp.umaxica.com")),
      palm_staff: OpenStruct.new(host: ENV.fetch("PALM_STAFF_URL", "palm-jp.umaxica.org")),
      help_service: OpenStruct.new(host: ENV.fetch("HELP_SERVICE_URL", "help.app.localhost")),
      help_corporate: OpenStruct.new(host: ENV.fetch("HELP_CORPORATE_URL", "help.com.localhost")),
      help_staff: OpenStruct.new(host: ENV.fetch("HELP_STAFF_URL", "help.org.localhost")),
    )

    Rails.configuration.x.stub(:boot_config, BootConfig.new(hosts)) do
      Rails.application.reload_routes!
      yield
    ensure
      Rails.application.reload_routes!
    end
  end
end

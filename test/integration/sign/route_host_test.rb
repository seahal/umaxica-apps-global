# typed: false
# frozen_string_literal: true

require "test_helper"
require "ostruct"

class SignRouteHostTest < ActionDispatch::IntegrationTest
  test "sign app routes match PRIVATE_SIGN_SERVICE_URL" do
    with_boot_config(sign_service_host: "auth.app.example.test") do
      host!("auth.app.example.test")

      route = Rails.application.routes.recognize_path("http://auth.app.example.test/", method: :get)

      assert_equal "auth/app/roots", route[:controller]
      assert_equal "index", route[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  test "sign com named root route points at sign/com/roots#index" do
    with_boot_config(sign_corporate_host: "auth.com.example.test") do
      route = Rails.application.routes.named_routes[:auth_com_root]

      assert_equal "/", route.path.spec.to_s
      assert_equal "auth/com/roots", route.defaults[:controller]
      assert_equal "index", route.defaults[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  test "sign org routes match SIGN_STAFF_URL" do
    with_boot_config(sign_staff_host: "auth.org.example.test") do
      host!("auth.org.example.test")

      route = Rails.application.routes.recognize_path("http://auth.org.example.test/", method: :get)

      assert_equal "auth/org/roots", route[:controller]
      assert_equal "index", route[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  test "sign routes accept internal origin and cloudflared public hosts" do
    {
      "auth.app.localhost" => "auth/app/roots",
      "auth.com.localhost" => "auth/com/roots",
      "auth.org.localhost" => "auth/org/roots",
      "log.umaxica.app" => "auth/app/roots",
      "log.umaxica.com" => "auth/com/roots",
      "log.umaxica.org" => "auth/org/roots",
    }.each do |host, controller|
      route = Rails.application.routes.recognize_path("http://#{host}/", method: :get)

      assert_equal controller, route[:controller]
      assert_equal "index", route[:action]
    end
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

  def with_boot_config(sign_service_host: ENV.fetch("PRIVATE_SIGN_SERVICE_URL"),
                       sign_corporate_host: ENV.fetch("SIGN_CORPORATE_URL"),
                       sign_staff_host: ENV.fetch("SIGN_STAFF_URL"))
    hosts = OpenStruct.new(
      auth_service: OpenStruct.new(host: sign_service_host),
      auth_corporate: OpenStruct.new(host: sign_corporate_host),
      auth_staff: OpenStruct.new(host: sign_staff_host),
      acme_service: OpenStruct.new(host: ENV.fetch("ACME_SERVICE_URL")),
      acme_corporate: OpenStruct.new(host: ENV.fetch("ACME_CORPORATE_URL")),
      acme_staff: OpenStruct.new(host: ENV.fetch("ACME_STAFF_URL")),
      sign_service: OpenStruct.new(host: ENV.fetch("PRIVATE_SIGN_SERVICE_URL")),
      sign_corporate: OpenStruct.new(host: ENV.fetch("SIGN_CORPORATE_URL")),
      sign_staff: OpenStruct.new(host: ENV.fetch("SIGN_STAFF_URL")),
      core_service: OpenStruct.new(host: ENV.fetch("CORE_SERVICE_URL")),
      core_corporate: OpenStruct.new(host: ENV.fetch("CORE_CORPORATE_URL")),
      core_staff: OpenStruct.new(host: ENV.fetch("CORE_STAFF_URL")),
      base_service: OpenStruct.new(host: ENV.fetch("BASE_SERVICE_URL")),
      base_corporate: OpenStruct.new(host: ENV.fetch("BASE_CORPORATE_URL")),
      base_staff: OpenStruct.new(host: ENV.fetch("BASE_STAFF_URL")),
      palm_service: OpenStruct.new(host: ENV.fetch("PALM_SERVICE_URL")),
      palm_corporate: OpenStruct.new(host: ENV.fetch("PALM_CORPORATE_URL")),
      palm_staff: OpenStruct.new(host: ENV.fetch("PALM_STAFF_URL")),
      help_service: OpenStruct.new(host: ENV.fetch("HELP_SERVICE_URL")),
      help_corporate: OpenStruct.new(host: ENV.fetch("HELP_CORPORATE_URL")),
      help_staff: OpenStruct.new(host: ENV.fetch("HELP_STAFF_URL")),
      info_service: OpenStruct.new(host: ENV.fetch("INFO_SERVICE_URL")),
      info_corporate: OpenStruct.new(host: ENV.fetch("INFO_CORPORATE_URL")),
      info_staff: OpenStruct.new(host: ENV.fetch("INFO_STAFF_URL")),
    )

    Rails.configuration.x.stub(:boot_config, BootConfig.new(hosts)) do
      Rails.application.reload_routes!
      yield
    ensure
      Rails.application.reload_routes!
    end
  end
end

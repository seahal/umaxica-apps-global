# typed: false
# frozen_string_literal: true

require "test_helper"
require "ostruct"

class SideRouteContractTest < ActionDispatch::IntegrationTest
  fixtures_none!

  test "side app route contract accepts the configured public host" do
    with_boot_config(side_service_host: "side-jp.example.test") do
      recognized = Rails.application.routes.recognize_path(
        "http://side-jp.example.test/",
        method: :get,
      )

      assert_equal "side/app/roots", recognized[:controller]
      assert_equal "index", recognized[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  test "side com route contract accepts the configured public host" do
    with_boot_config(side_corporate_host: "side-jp.example.test") do
      recognized = Rails.application.routes.recognize_path(
        "http://side-jp.example.test/",
        method: :get,
      )

      assert_equal "side/com/roots", recognized[:controller]
      assert_equal "index", recognized[:action]
    end
  ensure
    Rails.application.reload_routes!
  end

  test "side org route contract accepts the configured public host" do
    with_boot_config(side_staff_host: "side-jp.example.test") do
      recognized = Rails.application.routes.recognize_path(
        "http://side-jp.example.test/",
        method: :get,
      )

      assert_equal "side/org/roots", recognized[:controller]
      assert_equal "index", recognized[:action]
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

  def with_boot_config(side_service_host: ENV.fetch("SIDE_SERVICE_URL"),
                       side_corporate_host: ENV.fetch("SIDE_CORPORATE_URL"),
                       side_staff_host: ENV.fetch("SIDE_STAFF_URL"))
    hosts = OpenStruct.new(
      auth_service: OpenStruct.new(host: ENV.fetch("PRIVATE_SIGN_SERVICE_URL")),
      auth_corporate: OpenStruct.new(host: ENV.fetch("SIGN_CORPORATE_URL")),
      auth_staff: OpenStruct.new(host: ENV.fetch("SIGN_STAFF_URL")),
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
      side_service: OpenStruct.new(host: side_service_host),
      side_corporate: OpenStruct.new(host: side_corporate_host),
      side_staff: OpenStruct.new(host: side_staff_host),
    )

    Rails.configuration.x.stub(:boot_config, BootConfig.new(hosts)) do
      Rails.application.reload_routes!
      yield
    ensure
      Rails.application.reload_routes!
    end
  end
end

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

  HostSet = Struct.new(:sign_service, :sign_corporate, :sign_staff)
  BootConfig = Struct.new(:hosts)

  def with_boot_config(sign_service_host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
                       sign_corporate_host: ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
                       sign_staff_host: ENV.fetch("SIGN_STAFF_URL", "id.org.localhost"))
    hosts = HostSet.new(
      OpenStruct.new(host: sign_service_host),
      OpenStruct.new(host: sign_corporate_host),
      OpenStruct.new(host: sign_staff_host),
    )

    Rails.configuration.x.stub(:boot_config, BootConfig.new(hosts)) do
      Rails.application.reload_routes!
      yield
    ensure
      Rails.application.reload_routes!
    end
  end
end

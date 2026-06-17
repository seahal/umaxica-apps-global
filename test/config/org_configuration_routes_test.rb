# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgConfigurationRoutesTest < ActiveSupport::TestCase
  ROUTES = {
    sign: {
      org_host: ENV.fetch("SIGN_STAFF_URL", "id.org.localhost"),
      app_host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"),
      com_host: ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"),
      controller: "sign/org/configurations",
      helper: :sign_org_configuration_path,
    },
    acme: {
      org_host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
      app_host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      com_host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
      controller: "acme/org/configurations",
      helper: :acme_org_configuration_path,
    },
    core: {
      org_host: ENV.fetch("CORE_STAFF_URL", "www-jp.umaxica.org"),
      app_host: ENV.fetch("CORE_SERVICE_URL", "www-jp.umaxica.app"),
      com_host: ENV.fetch("CORE_CORPORATE_URL", "www-jp.umaxica.com"),
      controller: "core/org/configurations",
      helper: :core_org_configuration_path,
    },
  }.freeze

  test "org configuration routes resolve only on org hosts" do
    ROUTES.each_value do |entry|
      route = Rails.application.routes.named_routes[entry.fetch(:helper).to_s.delete_suffix("_path").to_sym]

      assert_equal "/configuration(.:format)", route.path.spec.to_s
      assert_equal entry.fetch(:controller), route.defaults.fetch(:controller)
      assert_equal "show", route.defaults.fetch(:action)

      assert_unrecognized(entry.fetch(:app_host), "/configuration", :get)
      assert_unrecognized(entry.fetch(:com_host), "/configuration", :get)
    end
  end

  test "org configuration helpers generate the reserved path" do
    helpers = Rails.application.routes.url_helpers

    ROUTES.each_value do |entry|
      assert_equal "/configuration", helpers.public_send(entry.fetch(:helper))
    end
  end

  private

  def assert_unrecognized(host, path, method)
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)
    end
  end
end

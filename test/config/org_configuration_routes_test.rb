# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OrgConfigurationRoutesTest < ActiveSupport::TestCase
  ROUTES = {
    sign: {
      org_host: ENV.fetch("PRIVATE_AUTH_STAFF_URL", "id.org.localhost"),
      app_host: ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "id.app.localhost"),
      com_host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "id.com.localhost"),
      controller: "sign/org/configurations",
      helper: :auth_org_configuration_path,
    },
    acme: {
      org_host: ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost"),
      app_host: ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost"),
      com_host: ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost"),
      controller: "acme/org/configurations",
      helper: :acme_org_configuration_path,
    },
    core: {
      org_host: ENV.fetch("PUBLIC_CORE_STAFF_URL", ENV.fetch("PUBLIC_CORE_STAFF_URL", "jpx.umaxica.org")),
      app_host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "jpx.umaxica.app")),
      com_host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "jpx.umaxica.com")),
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

# DAMP local route helper aliases for former shared test support.
class OrgConfigurationRoutesTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end

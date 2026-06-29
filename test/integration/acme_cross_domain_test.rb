# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# This test verifies cross-domain links between acme and other domains
class AcmeCrossDomainLinksTest < ActionDispatch::IntegrationTest
  test "acme layouts link to other domains correctly" do
    host! ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost")

    get acme_app_root_url(ri: "jp")

    assert_response :success

    # Acme layouts should have links to other domains
    assert_select "a[href^='http']", minimum: 1
  end

  test "cross domain url helpers are accessible from acme" do
    # Acme helpers should be accessible
    assert_respond_to self, :acme_app_root_url
    assert_respond_to self, :acme_com_root_url
    assert_respond_to self, :acme_org_root_url

    assert_respond_to self, :sign_app_root_url
  end
end

# DAMP local route helper aliases for former shared test support.
class AcmeCrossDomainLinksTest
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

# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcIssuerTest < ActiveSupport::TestCase
  HostSet = Struct.new(:acme_service, :acme_corporate, :acme_staff)

  test "host_for_resource_type normalizes url origins to host components" do
    hosts = HostSet.new(
      "https://www.app.example",
      "https://www.com.example:8443",
      "http://www.org.example",
    )
    boot_config = { hosts: hosts }

    Rails.configuration.x.stub(:boot_config, boot_config) do
      assert_equal "www.app.example", OidcIssuer.host_for_resource_type("client")
      assert_equal "www.com.example", OidcIssuer.host_for_resource_type("visitor")
      assert_equal "www.org.example", OidcIssuer.host_for_resource_type("operator")
    end
  end

  test "host_for_resource_type preserves bare hosts" do
    hosts = HostSet.new("www.app.example", "www.com.example", "www.org.example")
    boot_config = { hosts: hosts }

    Rails.configuration.x.stub(:boot_config, boot_config) do
      assert_equal "www.app.example", OidcIssuer.host_for_resource_type("client")
      assert_equal "www.com.example", OidcIssuer.host_for_resource_type("visitor")
      assert_equal "www.org.example", OidcIssuer.host_for_resource_type("operator")
    end
  end
end

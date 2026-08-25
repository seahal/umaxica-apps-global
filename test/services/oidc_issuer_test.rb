# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcIssuerTest < ActiveSupport::TestCase
  HostSet = Struct.new(:base_service, :base_corporate, :base_staff)

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

  test "jwt issuer ids use base namespaces" do
    assert_equal "surface:BASE_APP", OidcIssuer.jwt_issuer_id_for_resource_type("client")
    assert_equal "surface:BASE_COM", OidcIssuer.jwt_issuer_id_for_resource_type("visitor")
    assert_equal "surface:BASE_ORG", OidcIssuer.jwt_issuer_id_for_resource_type("operator")
  end

  test "resource type aliases use their canonical issuer hosts and namespaces" do
    hosts = HostSet.new("app.example", "com.example", "org.example")

    Rails.configuration.x.stub(:boot_config, { hosts: hosts }) do
      assert_equal "org.example", OidcIssuer.host_for_resource_type("staff")
      assert_equal "com.example", OidcIssuer.host_for_resource_type("customer")
      assert_equal "surface:BASE_ORG", OidcIssuer.jwt_issuer_id_for_resource_type("staff")
      assert_equal "surface:BASE_COM", OidcIssuer.jwt_issuer_id_for_resource_type("customer")
    end
  end

  test "client resource type aliases normalize before issuer selection" do
    assert_equal "operator", OidcIssuer.resource_type_for_client(Struct.new(:resource_type).new("staff"))
    assert_equal "visitor", OidcIssuer.resource_type_for_client(Struct.new(:resource_type).new("customer"))
    assert_equal "client", OidcIssuer.resource_type_for_client(Struct.new(:resource_type).new("client"))
  end

  test "issuer URLs preserve public origins and add the local development port" do
    assert_equal "https://accounts.example", OidcIssuer.absolute_url("https://accounts.example/")
    assert_equal "https://accounts.example", OidcIssuer.absolute_url("accounts.example")
    assert_equal "http://localhost:3000", OidcIssuer.absolute_url("localhost")
    assert_equal "http://127.0.0.1:4567", OidcIssuer.absolute_url("127.0.0.1:4567")
  end
end

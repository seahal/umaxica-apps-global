# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRpLogoutReceiversTest < ActionDispatch::IntegrationTest
  SURFACES = [
    { host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"), client_id: "sign-rp", resource_type: "client" },
    { host: ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost"), client_id: "sign-rp", resource_type: "visitor" },
    { host: ENV.fetch("SIGN_STAFF_URL", "id.org.localhost"), client_id: "sign-rp", resource_type: "operator" },
    { host: ENV.fetch("CORE_SERVICE_URL", "www.jp.umaxica.app"), client_id: "core-next-rp", resource_type: "client" },
    { host: ENV.fetch("CORE_CORPORATE_URL", "www.jp.umaxica.com"),
      client_id: "core-next-rp",
      resource_type: "visitor", },
    { host: ENV.fetch("CORE_STAFF_URL", "www.jp.umaxica.org"), client_id: "core-next-rp", resource_type: "operator" },
  ].freeze

  test "back-channel receiver accepts valid logout token idempotently" do
    SURFACES.each do |surface|
      with_oidc_key(namespace_for(surface.fetch(:resource_type))) do
        token = OidcLogoutTokenCodec.encode(
          client_id: surface.fetch(:client_id),
          resource_type: surface.fetch(:resource_type),
          subject: "subject-1",
          sid: SecureRandom.uuid,
        )

        post "https://#{surface.fetch(:host)}/oidc/backchannel_logout", params: { logout_token: token }

        assert_response :success, surface.inspect
      end
    end
  end

  test "back-channel receiver rejects invalid logout token" do
    SURFACES.each do |surface|
      post "https://#{surface.fetch(:host)}/oidc/backchannel_logout", params: { logout_token: "invalid" }

      assert_response :bad_request, surface.inspect
    end
  end

  test "front-channel receiver validates issuer" do
    SURFACES.each do |surface|
      get "https://#{surface.fetch(:host)}/oidc/frontchannel_logout",
          params: { iss: OidcIssuer.for_resource_type(surface.fetch(:resource_type)), sid: SecureRandom.uuid }

      assert_response :see_other, surface.inspect

      get "https://#{surface.fetch(:host)}/oidc/frontchannel_logout",
          params: { iss: "https://attacker.example", sid: SecureRandom.uuid }

      assert_response :bad_request, surface.inspect
    end
  end

  private

  def namespace_for(resource_type)
    case resource_type
    when "operator" then "ACME_ORG"
    when "visitor" then "ACME_COM"
    else "ACME_APP"
    end
  end

  def with_oidc_key(namespace)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    kid = "#{namespace.downcase.tr("_", "-")}-oidc-test"
    env = {
      "OIDC_CLIENT_#{namespace}_ACTIVE_KID" => kid,
      "OIDC_CLIENT_#{namespace}_PRIVATE_KEY" => Base64.strict_encode64(key.to_der),
    }
    previous = JitSecurityJwtRegistry.instance_variable_get(:@issuers)

    with_env(env) do
      JitSecurityJwtRegistry.reload!
      yield
    ensure
      JitSecurityJwtRegistry.instance_variable_set(:@issuers, previous)
    end
  end

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end

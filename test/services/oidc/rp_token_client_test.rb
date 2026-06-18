# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRpTokenClientTest < ActiveSupport::TestCase
  test "uses private_key_jwt when a client assertion key is configured" do
    captured = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = JSON.generate(id_token: "id-token")

    with_oidc_client_key("ACME_APP") do
      Net::HTTP.stub(
        :post_form, ->(_uri, params) {
                      captured = params
                      response
                    },
      ) do
        result = OidcRpTokenClient.call(
          token_url: "https://id.umaxica.app/oauth/token",
          client_id: "base-rails-rp",
          client_secret: nil,
          code: "code",
          redirect_uri: "https://www.umaxica.app/auth/callback",
          code_verifier: "verifier",
        )

        assert_predicate result, :success?
      end
    end

    assert_equal OidcClientAssertionJwt::ASSERTION_TYPE, captured.fetch(:client_assertion_type)
    assert_predicate captured.fetch(:client_assertion), :present?
    assert_not captured.key?(:client_secret)
  end

  private

  def with_oidc_client_key(namespace)
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

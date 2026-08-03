# typed: false
# frozen_string_literal: true

require "test_helper"

module OmniAuth
  module Strategies
    class UmaxicaEntraTest < ActiveSupport::TestCase
      TENANT_ID = "11111111-2222-3333-4444-555555555555"
      OBJECT_ID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

      setup do
        OrganizationEntraConnectionState.ensure_defaults!
        @connection = OrganizationEntraConnection.create!(
          organization_id: 1,
          entra_tenant_id: TENANT_ID,
          entra_client_id: "umaxica-entra-strategy-test-client",
          entra_credential_key: "umaxica-entra-strategy-test-secret",
          status_id: OrganizationEntraConnectionState::ACTIVE,
        )
      end

      test "request phase fails closed without a connection_public_id" do
        strategy = build_strategy(path: "/social/entra", params: {})

        strategy.request_phase

        assert_equal :connection_not_found, strategy.env["omniauth.error.type"]
      end

      test "request phase fails closed for an unknown or inactive connection" do
        strategy = build_strategy(path: "/social/entra", params: { "connection_public_id" => "does-not-exist" })

        strategy.request_phase

        assert_equal :connection_not_found, strategy.env["omniauth.error.type"]
      end

      test "request phase configures tenant-fixed endpoints and stores the connection reference" do
        strategy = build_strategy(
          path: "/social/entra",
          params: { "connection_public_id" => @connection.public_id },
        )
        strategy.stub(:redirect, nil) do
          strategy.request_phase
        end

        assert_equal "https://login.microsoftonline.com/#{TENANT_ID}/v2.0", strategy.options.issuer
        assert_equal "umaxica-entra-strategy-test-client", strategy.options.client_options.identifier
        assert_equal "/#{TENANT_ID}/oauth2/v2.0/authorize", strategy.options.client_options.authorization_endpoint
        assert_equal "/#{TENANT_ID}/oauth2/v2.0/token", strategy.options.client_options.token_endpoint
        assert_not strategy.options.discovery
        assert_equal @connection.public_id, strategy.send(:session)[OmniAuth::Strategies::UmaxicaEntra::CONNECTION_SESSION_KEY]
      end

      test "authorization URL never uses common/organizations/consumers and requests only openid profile" do
        strategy = build_strategy(
          path: "/social/entra",
          params: { "connection_public_id" => @connection.public_id },
        )
        redirect_target = nil
        strategy.stub(:redirect, ->(uri) { redirect_target = uri }) do
          strategy.request_phase
        end

        uri = URI.parse(redirect_target)
        query = Rack::Utils.parse_nested_query(uri.query)

        assert_equal "login.microsoftonline.com", uri.host
        assert_equal "/#{TENANT_ID}/oauth2/v2.0/authorize", uri.path
        assert_equal "openid profile", query.fetch("scope")
        assert_equal "S256", query.fetch("code_challenge_method")
        assert_predicate query.fetch("code_challenge"), :present?
        assert_predicate query.fetch("state"), :present?
        assert_predicate query.fetch("nonce"), :present?
      end

      test "callback phase fails closed when the session connection reference is missing or inactive" do
        strategy = build_strategy(
          path: "/social/entra/callback",
          params: {},
          session: {},
        )

        strategy.callback_phase

        assert_equal :connection_not_found, strategy.env["omniauth.error.type"]
      end

      test "access_token injects a certificate-based private_key_jwt assertion and consumes the PKCE verifier once" do
        strategy = build_strategy(
          path: "/social/entra/callback",
          params: {},
          session: {
            OmniAuth::Strategies::UmaxicaEntra::CONNECTION_SESSION_KEY => @connection.public_id,
            "omniauth.pkce.verifier" => "pkce-verifier-value",
            "omniauth.nonce" => "expected-nonce",
          },
        )
        strategy.instance_variable_set(:@entra_connection, @connection)

        captured = nil
        fake_client = Object.new
        fake_client.define_singleton_method(:access_token!) do |**kwargs|
          captured = kwargs
          OpenStruct.new(id_token: "fake-id-token")
        end
        strategy.instance_variable_set(:@client, fake_client)

        verified_result = ExternalSignIn::NormalizedAuthResult.new(
          tenant_id: TENANT_ID,
          entra_object_id: OBJECT_ID,
          evidence_issuer: "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
          evidence_subject: "pairwise-subject",
        )
        verifier_double = Minitest::Mock.new
        verifier_double.expect(:call, verified_result)

        private_key = OpenSSL::PKey::RSA.generate(2048)
        certificate = self_signed_certificate(private_key)
        credential = { private_key_pem: private_key.to_pem, certificate_pem: certificate.to_pem }

        ExternalSignIn::Providers::EntraId.stub(
          :new, ->(**kwargs) {
                  assert_equal "fake-id-token", kwargs.fetch(:id_token)
                  assert_equal "expected-nonce", kwargs.fetch(:expected_nonce)
                  assert_equal TENANT_ID, kwargs.fetch(:expected_tenant_id)
                  assert_equal @connection.entra_client_id, kwargs.fetch(:client_id)
                  verifier_double
                },
        ) do
          Rails.app.creds.stub(:option, credential) do
            strategy.access_token
          end
        end

        verifier_double.verify

        assert_equal :jwt_bearer, captured.fetch(:client_auth_method)
        assert_equal "pkce-verifier-value", captured.fetch(:code_verifier)
        assert_nil strategy.send(:session)["omniauth.pkce.verifier"]

        assertion = captured.fetch(:client_assertion)
        header = JSON.parse(Base64.urlsafe_decode64(assertion.split(".").first))

        assert_equal "PS256", header.fetch("alg")
        assert_predicate header.fetch("x5t#S256"), :present?

        payload = JSON.parse(Base64.urlsafe_decode64(assertion.split(".")[1]))

        assert_equal @connection.entra_client_id, payload.fetch("iss")
        assert_equal "https://login.microsoftonline.com/#{TENANT_ID}/oauth2/v2.0/token", payload.fetch("aud")

        assert_equal "#{TENANT_ID}:#{OBJECT_ID}", strategy.uid
        assert_equal({}, strategy.info)
        assert_equal({}, strategy.credentials)
        assert_equal(
          {
            "tid" => TENANT_ID,
            "oid" => OBJECT_ID,
            "iss" => "https://login.microsoftonline.com/#{TENANT_ID}/v2.0",
            "sub" => "pairwise-subject",
            "connection_public_id" => @connection.public_id,
          },
          strategy.extra.fetch(:raw_info),
        )
      end

      test "access_token fails closed when the certificate credential is unavailable" do
        strategy = build_strategy(
          path: "/social/entra/callback",
          params: {},
          session: {
            OmniAuth::Strategies::UmaxicaEntra::CONNECTION_SESSION_KEY => @connection.public_id,
            "omniauth.pkce.verifier" => "pkce-verifier-value",
          },
        )
        strategy.instance_variable_set(:@entra_connection, @connection)

        error = assert_raises(OmniAuth::Strategies::UmaxicaEntra::Error) { strategy.access_token }

        assert_equal :client_assertion_unavailable, error.reason
      end

      test "access_token fails closed when the PKCE verifier is missing" do
        strategy = build_strategy(
          path: "/social/entra/callback",
          params: {},
          session: {
            OmniAuth::Strategies::UmaxicaEntra::CONNECTION_SESSION_KEY => @connection.public_id,
          },
        )
        strategy.instance_variable_set(:@entra_connection, @connection)

        error = assert_raises(OmniAuth::Strategies::UmaxicaEntra::Error) { strategy.access_token }

        assert_equal :pkce_verifier_missing, error.reason
      end

      test "verify_id_token! raises instead of silently continuing on a missing id_token" do
        strategy = build_strategy(path: "/social/entra/callback", params: {}, session: {})
        strategy.instance_variable_set(:@entra_connection, @connection)

        error =
          strategy.stub(:stored_nonce, "expected-nonce") do
            assert_raises(OmniAuth::Strategies::UmaxicaEntra::Error) { strategy.verify_id_token!(nil) }
          end

        assert_equal :missing_id_token, error.reason
      end

      test "callback_phase converts a nested Error into fail! at the top level" do
        strategy = build_strategy(
          path: "/social/entra/callback",
          params: { "state" => "matching-state", "code" => "authorization-code" },
          session: {
            OmniAuth::Strategies::UmaxicaEntra::CONNECTION_SESSION_KEY => @connection.public_id,
            "omniauth.state" => "matching-state",
          },
        )

        strategy.stub(:access_token, -> { raise OmniAuth::Strategies::UmaxicaEntra::Error, :pkce_verifier_missing }) do
          strategy.callback_phase
        end

        assert_equal :pkce_verifier_missing, strategy.env["omniauth.error.type"]
      end

      private

      def self_signed_certificate(private_key)
        certificate = OpenSSL::X509::Certificate.new
        certificate.serial = 1
        certificate.version = 2
        certificate.subject = OpenSSL::X509::Name.parse("/CN=umaxica-entra-strategy-test")
        certificate.issuer = certificate.subject
        certificate.public_key = private_key.public_key
        certificate.not_before = 1.minute.ago
        certificate.not_after = 1.hour.from_now
        certificate.sign(private_key, OpenSSL::Digest::SHA256.new)
        certificate
      end

      def build_strategy(path:, params:, session: {})
        env = Rack::MockRequest.env_for(path, params: params, method: "GET")
        env["rack.session"] = session
        strategy = OmniAuth::Strategies::UmaxicaEntra.new(->(inner_env) { [404, {}, [inner_env.inspect]] })
        strategy.instance_variable_set(:@env, env)
        strategy
      end
    end
  end
end

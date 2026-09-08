# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdOidcEdgesTest < ActiveSupport::TestCase
  def service(**attrs)
    defaults = { grant_type: "authorization_code", code: "code", redirect_uri: "https://client/cb", client_id: "client", client_secret: nil, code_verifier: "verifier", client_assertion_type: nil, client_assertion: nil, dpop_proof: nil, token_endpoint_uri: nil }
    OidcTokenExchangeCoordinator.new(**defaults.merge(attrs))
  end

  test "OIDC client authentication covers public assertion and secret registrations" do
    public = Struct.new(:registered_token_endpoint_auth_method).new("none")
    OidcClientRegistry.stub(:find, public) do
      assert service.send(:authenticated_client?)
      assert_not service(client_secret: "secret").send(:authenticated_client?)
    end
    jwt = Struct.new(:registered_token_endpoint_auth_method).new("private_key_jwt")
    OidcClientRegistry.stub(:find, jwt) do
      assert_not service.send(:authenticated_client?)
      assert_not service(client_assertion_type: "wrong", client_assertion: "x", token_endpoint_uri: "https://token").send(:authenticated_client?)
      assert_not service(
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: nil,
        token_endpoint_uri: "https://token",
      ).send(:authenticated_client?)
    end
    secret = Struct.new(:registered_token_endpoint_auth_method).new("client_secret_post")
    OidcClientRegistry.stub(:find, secret) do
      OidcClientRegistry.stub(:authenticate, true) do
        assert service(client_secret: "secret").send(:authenticated_client?)
        assert_not service(client_assertion: "x").send(:authenticated_client?)
      end
    end
  end

  test "OIDC code validation covers all invalid grant reasons" do
    c = Struct.new(:expired?, :consumed?, :revoked?, :redirect_uri, :client_id, :resource_type).new(
      false, false,
      false, "https://client/cb", "client", "client",
    )
    root = Object.new
    svc = service
    svc.define_singleton_method(:root_token_from_authorization_code) { |_| root }
    OidcClientRegistry.stub(:valid_redirect_uri?, true) do
      assert_nil svc.send(:validate_code, c)
      %i(expired? consumed? revoked?).each do |name|
        c.define_singleton_method(name) { true }

        assert_equal "invalid_grant", svc.send(:validate_code, c).error
        c.define_singleton_method(name) { false }
      end
      svc.define_singleton_method(:root_token_from_authorization_code) { |_| nil }

      assert_equal "invalid_grant", svc.send(:validate_code, c).error
      svc.define_singleton_method(:root_token_from_authorization_code) { |_| root }
      c.redirect_uri = "other"

      assert_equal "invalid_request", svc.send(:validate_code, c).error
    end
  end

  test "OIDC scope and PKCE validators cover accepted and rejected inputs" do
    client = Struct.new(:allowed_scopes).new(%w(openid profile))
    code = Struct.new(:scope).new("openid profile")
    OidcClientRegistry.stub(:find!, client) do
      assert_nil service.send(:validate_authorized_scopes, code)
      code.scope = "profile"

      assert_equal "invalid_grant", service.send(:validate_authorized_scopes, code).error
    end
    code.define_singleton_method(:verify_pkce) { |value| value == "ok" }

    assert_equal "invalid_request", service(code_verifier: nil).send(:verify_pkce, code).error
    assert_nil service(code_verifier: "ok").send(:verify_pkce, code)
    assert_equal "invalid_request", service(code_verifier: "bad").send(:verify_pkce, code).error
  end

  test "OIDC class dispatch and token refresh helpers cover fallback cases" do
    svc = service

    assert_equal :client_token, svc.send(:parent_token_foreign_key_for, Class.new { def self.name = "Other" })
    assert_equal :operator_token, svc.send(
      :parent_token_foreign_key_for, Class.new {
                                       def self.name
                                         "OperatorTokenUsage"
                                       end
                                     },
    )
    assert_equal :visitor_token, svc.send(
      :parent_token_foreign_key_for, Class.new {
                                       def self.name
                                         "VisitorTokenUsage"
                                       end
                                     },
    )
    assert_raises(ArgumentError) { svc.send(:usage_class_for_root_token, Object.new) }
    usage = Object.new
    usage.define_singleton_method(:refresh_token_digest) { "digest" }
    usage.define_singleton_method(:rotate_refresh_token!) { :rotated }

    assert_equal :rotated, svc.send(:issue_or_rotate_usage_refresh_token!, usage)
    usage.define_singleton_method(:refresh_token_digest) { nil }
    usage.define_singleton_method(:issue_refresh_token!) { :issued }

    assert_equal :issued, svc.send(:issue_or_rotate_usage_refresh_token!, usage)
    usage.define_singleton_method(:oidc_jti) { nil }
    assert_raises(ArgumentError) { svc.send(:token_usage_oidc_jti, usage) }
  end
end

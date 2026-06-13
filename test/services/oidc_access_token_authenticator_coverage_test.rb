# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAccessTokenAuthenticatorCoverageTest < ActiveSupport::TestCase
  fixtures_none!

  test "returns invalid token when access token is blank" do
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: nil,
      resource_type: "client",
      host: "app.example.test",
    )

    result = authenticator.call

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects non dpop proof for cnf bound token" do
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
      authorization_scheme: "Bearer",
      dpop_proof: nil,
      request_method: "GET",
      request_uri: "/",
    )

    authenticator.stub(:find_token, nil) do
      AuthenticationTokenService.stub(:decode, { "cnf" => { "jkt" => "thumbprint" } }) do
        result = authenticator.call

        assert_not result.success?
        assert_equal "invalid_token", result.error
      end
    end
  end

  test "rejects tokens without openid scope" do
    resource = Client.create!(status_id: ClientStatus::ACTIVE)
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
    )
    token = Struct.new(:active?, :user).new(true, resource)

    AuthenticationTokenService.stub(:decode, { "scp" => [] }) do
      authenticator.stub(:dpop_valid?, true) do
        authenticator.stub(:find_token, token) do
          authenticator.stub(:token_belongs_to_audience?, true) do
            authenticator.stub(:token_jti_matches?, true) do
              authenticator.stub(:token_scope_allows_userinfo?, false) do
                result = authenticator.call

                assert_not result.success?
                assert_equal "insufficient_scope", result.error
              end
            end
          end
        end
      end
    end
  end

  test "returns success for a valid token and resource match" do
    resource = Client.create!(status_id: ClientStatus::ACTIVE)
    authenticator = OidcAccessTokenAuthenticator.new(
      access_token: "token",
      resource_type: "client",
      host: "app.example.test",
    )
    token = Struct.new(:active?, :user).new(true, resource)

    AuthenticationTokenService.stub(:decode, { "scp" => ["openid"] }) do
      authenticator.stub(:dpop_valid?, true) do
        authenticator.stub(:find_token, token) do
          authenticator.stub(:token_belongs_to_audience?, true) do
            authenticator.stub(:token_jti_matches?, true) do
              authenticator.stub(:token_scope_allows_userinfo?, true) do
                authenticator.stub(:token_resource, resource) do
                  authenticator.stub(:token_subject_matches?, true) do
                  result = authenticator.call

                  assert_predicate result, :success?
                  assert_equal resource, result.resource
                  assert_equal token, result.token
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

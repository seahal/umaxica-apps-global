# typed: false
# frozen_string_literal: true

require "test_helper"

class OmniauthGoogleStrategyContractTest < ActiveSupport::TestCase
  test "pinned strategy uses online access, PKCE, nonce, and only the openid scope" do
    strategy = OmniAuth::Strategies::GoogleOauth2.new(
      ->(_env) { [200, {}, ["ok"]] },
      "contract-client",
      "contract-secret",
      access_type: "online",
      scope: "openid",
      pkce: true,
    )
    env = Rack::MockRequest.env_for("/social/google")
    env["rack.session"] = {}
    strategy.instance_variable_set(:@env, env)

    params = strategy.authorize_params

    assert_equal "online", params[:access_type]
    assert_equal "openid", params[:scope]
    assert_equal "S256", params[:code_challenge_method]
    assert_predicate params[:code_challenge], :present?
    assert_predicate params[:nonce], :present?
    assert_equal params[:nonce], env.fetch("rack.session").fetch("omniauth.nonce")
  end

  test "verified ID token subject is authoritative and UserInfo is never called" do
    travel_to Time.zone.local(2026, 7, 24, 12, 0, 0) do
      nonce = "contract-nonce"
      signing_key = OpenSSL::PKey::RSA.generate(2048)
      id_token = JWT.encode(
        {
          "iss" => "https://accounts.google.com",
          "aud" => "contract-client",
          "sub" => "verified-id-token-subject",
          "nonce" => nonce,
          "iat" => Time.current.to_i,
          "exp" => 5.minutes.from_now.to_i,
        },
        signing_key,
        "RS256",
        { kid: "contract-key" },
      )
      strategy = OmniAuth::Strategies::GoogleOauth2.new(
        ->(_env) { [200, {}, ["ok"]] },
        "contract-client",
        "contract-secret",
      )
      env = Rack::MockRequest.env_for("/social/google/callback")
      env["rack.session"] = { "omniauth.nonce" => nonce }
      strategy.instance_variable_set(:@env, env)
      oauth_client = OAuth2::Client.new("contract-client", "contract-secret")
      access_token = OAuth2::AccessToken.new(
        oauth_client,
        "callback-access-token",
        "id_token" => id_token,
      )
      strategy.access_token = access_token
      access_token.define_singleton_method(:get) { |_| raise RuntimeError, "UserInfo must not be called" }
      jwks = { "keys" => [JWT::JWK.new(signing_key.public_key, kid: "contract-key").export] }

      strategy.stub(:google_jwks_loader, ->(_options = {}) { jwks }) do
        assert_equal "verified-id-token-subject", strategy.uid
        assert_empty strategy.info
        assert_empty strategy.extra
      end
      assert_nil env.fetch("rack.session")["omniauth.nonce"]
    end
  end

  test "unsigned ID token cannot establish a uid" do
    strategy = OmniAuth::Strategies::GoogleOauth2.new(
      ->(_env) { [200, {}, ["ok"]] },
      "contract-client",
      "contract-secret",
    )
    env = Rack::MockRequest.env_for("/social/google/callback")
    env["rack.session"] = { "omniauth.nonce" => "contract-nonce" }
    strategy.instance_variable_set(:@env, env)
    oauth_client = OAuth2::Client.new("contract-client", "contract-secret")
    unsigned_id_token = JWT.encode(
      {
        "iss" => "https://accounts.google.com",
        "aud" => "contract-client",
        "sub" => "forged-subject",
        "nonce" => "contract-nonce",
        "iat" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
      },
      nil,
      "none",
    )
    access_token = OAuth2::AccessToken.new(
      oauth_client,
      "callback-access-token",
      "id_token" => unsigned_id_token,
    )
    strategy.access_token = access_token

    assert_raises(OmniAuth::Strategies::OAuth2::CallbackError) { strategy.uid }
  end

  test "authorization code exchange failure returns an OmniAuth failure without auth" do
    strategy = OmniAuth::Strategies::GoogleOauth2.new(
      ->(_env) { [200, {}, ["unexpected success"]] },
      "contract-client",
      "contract-secret",
      name: "google",
      callback_path: "/social/google/callback",
    )
    env = Rack::MockRequest.env_for(
      "/social/google/callback?code=invalid-code&state=contract-state",
    )
    env["rack.session"] = { "omniauth.state" => "contract-state" }
    strategy.instance_variable_set(:@env, env)
    exchange_error = OAuth2::Error.new(
      "error" => "invalid_grant",
      "error_description" => "contract boundary failure",
    )

    response =
      strategy.stub(:build_access_token, -> { raise exchange_error }) do
        strategy.callback_phase
      end

    assert_equal 302, response.fetch(0)
    assert_includes response.fetch(1).fetch("location"), "message=invalid_credentials"
    assert_nil env["omniauth.auth"]
  end
end

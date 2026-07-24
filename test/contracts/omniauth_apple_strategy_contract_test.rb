# typed: false
# frozen_string_literal: true

require "test_helper"

class OmniauthAppleStrategyContractTest < ActiveSupport::TestCase
  test "authorization request generates one nonce and stores the value for callback verification" do
    strategy = OmniAuth::Strategies::Apple.new(
      ->(_env) { [200, {}, ["ok"]] },
      "contract-client",
      "",
      authorized_client_ids: ["contract-client"],
    )
    env = Rack::MockRequest.env_for("/social/apple")
    env["rack.session"] = {}
    strategy.instance_variable_set(:@env, env)

    params = strategy.authorize_params

    assert_predicate params[:nonce], :present?
    assert_equal params[:nonce], env.fetch("rack.session").fetch("omniauth.nonce")
  end

  test "signed ID token with the stored nonce succeeds through the pinned strategy" do
    travel_to Time.zone.local(2026, 7, 24, 12, 0, 0) do
      signing_key = OpenSSL::PKey::RSA.generate(2048)
      verification_key = JSON::JWK.new(signing_key.public_key)
      verification_key[:kid] = "contract-kid"
      id_token = JSON::JWT.new(
        iss: "https://appleid.apple.com",
        aud: "contract-client",
        sub: "contract-subject",
        iat: Time.current.to_i,
        exp: 5.minutes.from_now.to_i,
        nonce: "contract-nonce",
        nonce_supported: true,
      )
      id_token.kid = "contract-kid"
      signed_id_token = id_token.sign(signing_key, :RS256).to_s
      strategy = OmniAuth::Strategies::Apple.new(
        ->(_env) { [200, {}, ["ok"]] },
        "contract-client",
        "",
        authorized_client_ids: ["contract-client"],
      )
      env = Rack::MockRequest.env_for("/social/apple/callback")
      env["rack.session"] = { "omniauth.nonce" => "contract-nonce" }
      strategy.instance_variable_set(:@env, env)
      oauth_client = OAuth2::Client.new("contract-client", "contract-secret")
      strategy.access_token = OAuth2::AccessToken.new(
        oauth_client,
        "callback-access-token",
        "id_token" => signed_id_token,
      )

      auth_hash =
        JSON::JWK::Set::Fetcher.stub(:fetch, verification_key) do
          strategy.auth_hash
        end

      assert_equal "contract-subject", auth_hash.uid
      assert_empty env.fetch("rack.session")
    end
  end

  test "signed ID token with a different nonce is rejected by the pinned strategy" do
    travel_to Time.zone.local(2026, 7, 24, 12, 0, 0) do
      signing_key = OpenSSL::PKey::RSA.generate(2048)
      verification_key = JSON::JWK.new(signing_key.public_key)
      verification_key[:kid] = "contract-kid"
      id_token = JSON::JWT.new(
        iss: "https://appleid.apple.com",
        aud: "contract-client",
        sub: "contract-subject",
        iat: Time.current.to_i,
        exp: 5.minutes.from_now.to_i,
        nonce: "different-nonce",
        nonce_supported: true,
      )
      id_token.kid = "contract-kid"
      signed_id_token = id_token.sign(signing_key, :RS256).to_s
      strategy = OmniAuth::Strategies::Apple.new(
        ->(_env) { [200, {}, ["ok"]] },
        "contract-client",
        "",
        authorized_client_ids: ["contract-client"],
      )
      env = Rack::MockRequest.env_for("/social/apple/callback")
      env["rack.session"] = { "omniauth.nonce" => "contract-nonce" }
      strategy.instance_variable_set(:@env, env)
      oauth_client = OAuth2::Client.new("contract-client", "contract-secret")
      strategy.access_token = OAuth2::AccessToken.new(
        oauth_client,
        "callback-access-token",
        "id_token" => signed_id_token,
      )

      error =
        assert_raises(OmniAuth::Strategies::OAuth2::CallbackError) do
          JSON::JWK::Set::Fetcher.stub(:fetch, verification_key) do
            strategy.auth_hash
          end
        end

      assert_includes error.message, "nonce invalid"
    end
  end

  test "signed ID token without nonce is rejected when the request stored a nonce" do
    travel_to Time.zone.local(2026, 7, 24, 12, 0, 0) do
      signing_key = OpenSSL::PKey::RSA.generate(2048)
      verification_key = JSON::JWK.new(signing_key.public_key)
      verification_key[:kid] = "contract-kid"
      id_token = JSON::JWT.new(
        iss: "https://appleid.apple.com",
        aud: "contract-client",
        sub: "contract-subject",
        iat: Time.current.to_i,
        exp: 5.minutes.from_now.to_i,
      )
      id_token.kid = "contract-kid"
      signed_id_token = id_token.sign(signing_key, :RS256).to_s
      strategy = OmniAuth::Strategies::Apple.new(
        ->(_env) { [200, {}, ["ok"]] },
        "contract-client",
        "",
        authorized_client_ids: ["contract-client"],
      )
      env = Rack::MockRequest.env_for("/social/apple/callback")
      env["rack.session"] = { "omniauth.nonce" => "contract-nonce" }
      strategy.instance_variable_set(:@env, env)
      oauth_client = OAuth2::Client.new("contract-client", "contract-secret")
      strategy.access_token = OAuth2::AccessToken.new(
        oauth_client,
        "callback-access-token",
        "id_token" => signed_id_token,
      )

      error =
        assert_raises(OmniAuth::Strategies::OAuth2::CallbackError) do
          JSON::JWK::Set::Fetcher.stub(:fetch, verification_key) do
            strategy.auth_hash
          end
        end

      assert_includes error.message, "nonce invalid"
    end
  end

  test "a consumed nonce cannot validate a second strategy callback" do
    travel_to Time.zone.local(2026, 7, 24, 12, 0, 0) do
      signing_key = OpenSSL::PKey::RSA.generate(2048)
      verification_key = JSON::JWK.new(signing_key.public_key)
      verification_key[:kid] = "contract-kid"
      id_token = JSON::JWT.new(
        iss: "https://appleid.apple.com",
        aud: "contract-client",
        sub: "contract-subject",
        iat: Time.current.to_i,
        exp: 5.minutes.from_now.to_i,
        nonce: "contract-nonce",
        nonce_supported: true,
      )
      id_token.kid = "contract-kid"
      signed_id_token = id_token.sign(signing_key, :RS256).to_s
      oauth_client = OAuth2::Client.new("contract-client", "contract-secret")
      shared_session = { "omniauth.nonce" => "contract-nonce" }
      first_strategy = OmniAuth::Strategies::Apple.new(
        ->(_env) { [200, {}, ["ok"]] },
        "contract-client",
        "",
        authorized_client_ids: ["contract-client"],
      )
      first_env = Rack::MockRequest.env_for("/social/apple/callback")
      first_env["rack.session"] = shared_session
      first_strategy.instance_variable_set(:@env, first_env)
      first_strategy.access_token = OAuth2::AccessToken.new(
        oauth_client,
        "first-callback-access-token",
        "id_token" => signed_id_token,
      )
      second_strategy = OmniAuth::Strategies::Apple.new(
        ->(_env) { [200, {}, ["ok"]] },
        "contract-client",
        "",
        authorized_client_ids: ["contract-client"],
      )
      second_env = Rack::MockRequest.env_for("/social/apple/callback")
      second_env["rack.session"] = shared_session
      second_strategy.instance_variable_set(:@env, second_env)
      second_strategy.access_token = OAuth2::AccessToken.new(
        oauth_client,
        "second-callback-access-token",
        "id_token" => signed_id_token,
      )

      JSON::JWK::Set::Fetcher.stub(:fetch, verification_key) do
        assert_equal "contract-subject", first_strategy.auth_hash.uid
      end
      error =
        assert_raises(OmniAuth::Strategies::OAuth2::CallbackError) do
          JSON::JWK::Set::Fetcher.stub(:fetch, verification_key) do
            second_strategy.auth_hash
          end
        end

      assert_includes error.message, "nonce invalid"
    end
  end
end

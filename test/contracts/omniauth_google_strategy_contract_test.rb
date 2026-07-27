# typed: false
# frozen_string_literal: true

require "test_helper"

class OmniauthGoogleStrategyContractTest < ActiveSupport::TestCase
  test "pinned strategy preserves explicitly configured online access" do
    strategy = OmniAuth::Strategies::GoogleOauth2.new(
      ->(_env) { [200, {}, ["ok"]] },
      "contract-client",
      "contract-secret",
      access_type: "online",
      scope: "openid profile",
    )
    env = Rack::MockRequest.env_for("/social/google")
    env["rack.session"] = {}
    strategy.instance_variable_set(:@env, env)

    params = strategy.authorize_params

    assert_equal "online", params[:access_type]
    assert_equal "openid profile", params[:scope]
  end

  test "top-level uid is established by the UserInfo subject" do
    strategy = OmniAuth::Strategies::GoogleOauth2.new(
      ->(_env) { [200, {}, ["ok"]] },
      "contract-client",
      "contract-secret",
    )
    env = Rack::MockRequest.env_for("/social/google/callback")
    env["rack.session"] = {}
    strategy.instance_variable_set(:@env, env)
    oauth_client = OAuth2::Client.new("contract-client", "contract-secret")
    access_token = OAuth2::AccessToken.new(oauth_client, "callback-access-token")
    strategy.access_token = access_token
    user_info_response = Struct.new(:parsed).new(
      {
        "sub" => "userinfo-subject",
        "name" => "Discarded Profile Name",
        "picture" => "https://example.test/discarded.png",
      },
    )

    uid =
      access_token.stub(:get, user_info_response) do
        strategy.uid
      end

    assert_equal "userinfo-subject", uid
  end

  test "unsigned id_info subject does not replace the UserInfo subject" do
    travel_to Time.zone.local(2026, 7, 24, 12, 0, 0) do
      unsigned_id_token = JWT.encode(
        {
          "iss" => "https://accounts.google.com",
          "aud" => "contract-client",
          "sub" => "forged-id-info-subject",
          "exp" => 5.minutes.from_now.to_i,
          "nbf" => 1.minute.ago.to_i,
        },
        nil,
        "none",
      )
      strategy = OmniAuth::Strategies::GoogleOauth2.new(
        ->(_env) { [200, {}, ["ok"]] },
        "contract-client",
        "contract-secret",
      )
      env = Rack::MockRequest.env_for("/social/google/callback")
      env["rack.session"] = {}
      strategy.instance_variable_set(:@env, env)
      oauth_client = OAuth2::Client.new("contract-client", "contract-secret")
      access_token = OAuth2::AccessToken.new(
        oauth_client,
        "callback-access-token",
        "id_token" => unsigned_id_token,
      )
      strategy.access_token = access_token
      user_info_response = Struct.new(:parsed).new({ "sub" => "userinfo-subject" })

      uid =
        access_token.stub(:get, user_info_response) do
          strategy.uid
        end
      extra =
        access_token.stub(:get, user_info_response) do
          strategy.extra
        end

      assert_equal "userinfo-subject", uid
      assert_equal "forged-id-info-subject", extra.fetch(:id_info).fetch("sub")
      assert_equal "userinfo-subject", strategy.uid
    end
  end

  test "UserInfo failure cannot establish a uid" do
    strategy = OmniAuth::Strategies::GoogleOauth2.new(
      ->(_env) { [200, {}, ["ok"]] },
      "contract-client",
      "contract-secret",
    )
    env = Rack::MockRequest.env_for("/social/google/callback")
    env["rack.session"] = {}
    strategy.instance_variable_set(:@env, env)
    oauth_client = OAuth2::Client.new("contract-client", "contract-secret")
    access_token = OAuth2::AccessToken.new(oauth_client, "callback-access-token")
    strategy.access_token = access_token
    user_info_error = OAuth2::Error.new(
      "error" => "userinfo_unavailable",
      "error_description" => "contract boundary failure",
    )

    error =
      assert_raises(OAuth2::Error) do
        access_token.stub(:get, ->(*) { raise user_info_error }) do
          strategy.uid
        end
      end

    assert_equal "userinfo_unavailable", error.code
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

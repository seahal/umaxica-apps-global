# typed: false
# frozen_string_literal: true

require "test_helper"

class OmniauthTest < ActiveSupport::TestCase
  test "callback origin uses https for configured app sign host" do
    env = Rack::MockRequest.env_for(
      "http://id.umaxica.app/auth/google_app",
      "HTTP_HOST" => "id.umaxica.app",
    )

    OmniAuthCallbackOrigin.stub(:public_sign_hosts, ["id.umaxica.app"]) do
      assert_equal "https://id.umaxica.app", OmniAuthCallbackOrigin.call(env)
    end
  end

  test "callback origin uses https for configured org sign host" do
    env = Rack::MockRequest.env_for(
      "http://id.umaxica.org/auth/failure",
      "HTTP_HOST" => "id.umaxica.org",
    )

    OmniAuthCallbackOrigin.stub(:public_sign_hosts, ["id.umaxica.org"]) do
      assert_equal "https://id.umaxica.org", OmniAuthCallbackOrigin.call(env)
    end
  end

  test "callback origin preserves request scheme for unconfigured hosts" do
    env = Rack::MockRequest.env_for(
      "http://id.app.localhost/auth/google_app",
      "HTTP_HOST" => "id.app.localhost",
    )

    OmniAuthCallbackOrigin.stub(:public_sign_hosts, []) do
      assert_equal "http://id.app.localhost", OmniAuthCallbackOrigin.call(env)
    end
  end
end

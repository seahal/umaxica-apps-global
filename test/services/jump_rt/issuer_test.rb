# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpRt::IssuerTest < ActiveSupport::TestCase
  fixtures_none!

  setup do
    @private_key = OpenSSL::PKey::EC.generate("secp384r1")
  end

  test "issues ES384 jump rt jwt with expected claims" do
    with_env(
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a",
      "SIGN_SERVICE_URL" => "sign.example.test",
      "JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
    ) do
      JumpRt::Keyring.stub(:private_key, @private_key) do
        token = JumpRt::Issuer.call(
          namespace: "SIGN_APP",
          url: "https://target.example/path?ok=1",
          dst: "internal",
          now: Time.zone.at(1_800_000_000),
          jti: "jti-test",
        )
        JWT.decode(
          token, @private_key.public_key, true, algorithms: ["ES384"], verify_iat: false,
                                                verify_expiration: false, verify_not_before: false,
        )
        payload, header = JWT.decode(token, nil, false)

        assert_equal "JWT", header["typ"]
        assert_equal "ES384", header["alg"]
        assert_equal "sign-app-es384-test-a", header["kid"]
        assert_equal 1, payload["schema"]
        assert_equal "jump-redirect", payload["sub"]
        assert_equal "internal", payload["dst"]
        assert_equal "reuse", payload["rpl"]
        assert_equal "https://target.example/path?ok=1", payload["url"]
        assert_equal "jti-test", payload["jti"]
      end
    end
  end

  test "can mark issued jump rt as one-time replay policy" do
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRt::Keyring.stub(:private_key, @private_key) do
        token = JumpRt::Issuer.call(
          namespace: "SIGN_APP",
          url: "https://target.example/path",
          replay_policy: "once",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "once", payload["rpl"]
      end
    end
  end

  test "refuses invalid replay policy" do
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRt::Keyring.stub(:private_key, @private_key) do
        token = JumpRt::Issuer.call(
          namespace: "SIGN_APP",
          url: "https://target.example/path",
          replay_policy: "single",
        )

        assert_nil token
      end
    end
  end

  test "uses environment configured ttl when ttl is omitted" do
    with_env(
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a",
      "SIGN_SERVICE_URL" => "sign.example.test",
      "JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
      "JUMP_RT_TTL_SECONDS" => "60",
    ) do
      JumpRt::Keyring.stub(:private_key, @private_key) do
        token = JumpRt::Issuer.call(
          namespace: "SIGN_APP",
          url: "https://target.example/path",
          now: Time.zone.at(1_800_000_000),
          jti: "jti-test",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal 1_800_000_000, payload["iat"]
        assert_equal 1_800_000_060, payload["exp"]
      end
    end
  end

  test "refuses invalid destination kind" do
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRt::Keyring.stub(:private_key, @private_key) do
        token = JumpRt::Issuer.call(namespace: "SIGN_APP", url: "https://target.example/", dst: "unknown")

        assert_nil token
      end
    end
  end

  test "refuses unsafe destination urls" do
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRt::Keyring.stub(:private_key, @private_key) do
        assert_nil JumpRt::Issuer.call(namespace: "SIGN_APP", url: "javascript:alert(1)")
        assert_nil JumpRt::Issuer.call(namespace: "SIGN_APP", url: "https://user:pass@target.example/")
        assert_nil JumpRt::Issuer.call(namespace: "SIGN_APP", url: "https://target.example/#fragment")
        assert_nil JumpRt::Issuer.call(namespace: "SIGN_APP", url: "https://target.example/\n")
      end
    end
  end

  test "strips redirect-target query keys before signing the url" do
    with_env(
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a",
      "SIGN_SERVICE_URL" => "sign.example.test",
    ) do
      JumpRt::Keyring.stub(:private_key, @private_key) do
        token = JumpRt::Issuer.call(
          namespace: "SIGN_APP",
          url: "https://target.example/path?ok=1&pt=/evil&rt=stale&xt=foo&keep=2",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "https://target.example/path?ok=1&keep=2", payload["url"]
      end
    end
  end

  test "drops query entirely when only redirect-target keys are present" do
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRt::Keyring.stub(:private_key, @private_key) do
        token = JumpRt::Issuer.call(
          namespace: "SIGN_APP",
          url: "https://target.example/path?rt=stale&pt=/evil",
        )
        payload, = JWT.decode(token, nil, false)

        assert_equal "https://target.example/path", payload["url"]
      end
    end
  end

  test "refuses missing key material" do
    with_env("JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a") do
      JumpRt::Keyring.stub(:private_key, nil) do
        assert_nil JumpRt::Issuer.call(namespace: "SIGN_APP", url: "https://target.example/")
      end
    end
  end

  test "refuses unsupported issuer surface" do
    assert_raises(ArgumentError) do
      JumpRt::Issuer.call(namespace: "JUMP_APP", url: "https://target.example/")
    end
  end

  test "resolves issuer namespace from controller class name" do
    assert_equal "SIGN_APP", JumpRt::Surface.namespace_for_controller("Sign::App::DashboardsController")
    assert_equal "SIGN_COM", JumpRt::Surface.namespace_for_controller("Sign::Com::DashboardsController")
    assert_equal "SIGN_ORG", JumpRt::Surface.namespace_for_controller("Sign::Org::DashboardsController")
    assert_equal "ACME_APP", JumpRt::Surface.namespace_for_controller("Acme::App::RootsController")
    assert_equal "CORE_ORG", JumpRt::Surface.namespace_for_controller("Core::Org::RootsController")
    assert_nil JumpRt::Surface.namespace_for_controller("Jump::App::RootsController")
  end

  private

  def with_env(values)
    previous = values.transform_values { |_value| nil }
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

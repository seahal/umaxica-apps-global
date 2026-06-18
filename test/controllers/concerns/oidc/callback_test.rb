# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcCallbackTestController < ApplicationController
  def self.declare_authentication_mode!(*)
  end

  include OidcCallback

  def seed
    session[:oidc_code_verifier] = params[:code_verifier] if params.key?(:code_verifier)
    session[:oidc_state] = params[:state] if params.key?(:state)
    session[:oidc_nonce] = params[:nonce] if params.key?(:nonce)
    session[:oidc_pt] = params[:pt] if params.key?(:pt)

    head :no_content
  end

  def oidc_client_id
    "base-rails-rp"
  end

  def oidc_client_secret
    OidcClientRegistry.find!("base-rails-rp").client_secret
  end

  def oidc_token_url
    "http://id.app.localhost/oauth/token"
  end

  def oidc_callback_url
    OidcClientRegistry.find!("base-rails-rp").redirect_uris.first
  end

  def oidc_resource_type
    "client"
  end

  def sign_in_url_with_pt(_return_to)
    "https://id.app.localhost/sign/in"
  end

  def provision_rp_account_from_id_token!(payload)
    Struct.new(:id).new(payload.fetch("sub"))
  end

  def log_in(resource, **kwargs)
    @logged_in_resource = resource
    @login_kwargs = kwargs
    { status: :success }
  end
end

class OidcCallbackTest < ActionDispatch::IntegrationTest
  fixtures_none!

  setup do
    Rails.application.routes.draw do
      get "/oidc/callback/session" => "oidc_callback_test#seed"
      get "/oidc/callback" => "oidc_callback_test#show"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  Result = Struct.new(:success?, :token_response, :error, :error_description, keyword_init: true)

  test "show redirects to pt on successful exchange" do
    get "/oidc/callback/session",
        params: { code_verifier: "verifier", state: "state", nonce: "nonce", pt: "/after" }

    result = Result.new(
      success?: true,
      token_response: { access_token: "access", refresh_token: "refresh", id_token: "id-token" },
      error: nil,
      error_description: nil,
    )
    id_token_result = Struct.new(:success?, :payload, :error, keyword_init: true).new(
      success?: true,
      payload: { "sub" => "42", "nonce" => "nonce" },
      error: nil,
    )

    OidcRpTokenClient.stub(:call, result) do
      OidcIdTokenVerifier.stub(:call, id_token_result) do
        get "/oidc/callback", params: { code: "abc", state: "state" }
      end
    end

    assert_response :redirect
    assert_redirected_to "/after"
  end

  test "show redirects to sign in on failed exchange" do
    get "/oidc/callback/session", params: { code_verifier: "verifier", state: "state" }

    result = Result.new(
      success?: false,
      token_response: nil,
      error: "bad",
      error_description: "bad",
    )
    logged = []

    OidcRpTokenClient.stub(:call, result) do
      Rails.logger.stub(
        :info, ->(message = nil, &block) {
                 message = block.call if message.nil? && block
                 logged << JSON.parse(message, symbolize_names: true) if message.to_s.start_with?("{")
               },
      ) do
        get "/oidc/callback", params: { code: "abc", state: "state" }
      end
    end

    assert_response :redirect
    assert_redirected_to "https://id.app.localhost/sign/in"
    assert_equal 1, logged.count { |entry| entry[:event] == "oidc.rp.callback.failed" }
  end

  test "show rejects mismatched state before token exchange" do
    get "/oidc/callback/session", params: { state: "expected" }

    OidcRpTokenClient.stub(:call, ->(**) { flunk("token exchange should not run for state mismatch") }) do
      get "/oidc/callback", params: { code: "abc", state: "wrong" }
    end

    assert_response :unprocessable_content
  end

  test "show raises unexpected provisioning errors" do
    get "/oidc/callback/session",
        params: { code_verifier: "verifier", state: "state", nonce: "nonce" }

    result = Result.new(
      success?: true,
      token_response: { access_token: "access", refresh_token: "refresh", id_token: "id-token" },
      error: nil,
      error_description: nil,
    )
    id_token_result = Struct.new(:success?, :payload, :error, keyword_init: true).new(
      success?: true,
      payload: { "nonce" => "nonce" },
      error: nil,
    )

    OidcRpTokenClient.stub(:call, result) do
      OidcIdTokenVerifier.stub(:call, id_token_result) do
        assert_raises(KeyError) do
          get "/oidc/callback", params: { code: "abc", state: "state" }
        end
      end
    end
  end

  test "default oidc_client_id raises NotImplementedError" do
    # create a dummy controller without overriding
    dummy_class =
      Class.new(ApplicationController) do
        def self.declare_authentication_mode!(*)
        end

        include OidcCallback
      end

    assert_raises(NotImplementedError) do
      dummy_class.new.send(:oidc_client_id)
    end
  end

  test "oidc_client_secret_credential uses ClientRegistry" do
    dummy_class =
      Class.new(ApplicationController) do
        def self.declare_authentication_mode!(*)
        end

        include OidcCallback

        define_method(:oidc_client_id) do
          "test-client"
        end
      end

    client_mock = Struct.new(:client_secret).new("mock_secret_credential")

    OidcClientRegistry.stub(:find, client_mock) do
      assert_equal "mock_secret_credential", dummy_class.new.send(:oidc_client_secret)
    end
  end
end

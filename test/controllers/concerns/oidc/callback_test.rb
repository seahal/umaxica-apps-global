# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcCallbackTestController < ApplicationController
  class << self
    attr_accessor :login_result_for_test, :last_login_kwargs, :last_session_limit_gate_pt, :hard_reject_payload
  end

  def self.declare_authentication_mode!(*)
  end

  include OidcCallback

  def seed
    session[:oidc_code_verifier] = params[:code_verifier] if params.key?(:code_verifier)
    session[:oidc_state] = params[:state] if params.key?(:state)
    session[:oidc_nonce] = params[:nonce] if params.key?(:nonce)
    session[:oidc_pt] = params[:pt] if params.key?(:pt)
    if params[:pending_state].present?
      session["oidc_pending_flows"] ||= {}
      session["oidc_pending_flows"][params[:pending_state]] = {
        "code_verifier" => params[:pending_code_verifier],
        "nonce" => params[:pending_nonce],
        "pt" => params[:pending_pt],
        "created_at" => Time.current.to_i,
      }
    end

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

  def sign_app_sign_in_session_path
    "/sign/in/session"
  end

  def provision_rp_account_from_id_token!(payload)
    Struct.new(:id).new(payload.fetch("sub"))
  end

  def log_in(resource, **kwargs)
    @logged_in_resource = resource
    @login_kwargs = kwargs
    self.class.last_login_kwargs = kwargs
    self.class.last_session_limit_gate_pt = send(:session_limit_gate_pt)
    self.class.login_result_for_test || { status: :success }
  end

  def render_session_limit_hard_reject(message: nil, http_status: nil)
    self.class.hard_reject_payload = { message: message, http_status: http_status }
    render plain: message, status: http_status
  end
end

class OidcCallbackTest < ActionDispatch::IntegrationTest
  fixtures_none!

  setup do
    OidcCallbackTestController.login_result_for_test = nil
    OidcCallbackTestController.last_login_kwargs = nil
    OidcCallbackTestController.last_session_limit_gate_pt = nil
    OidcCallbackTestController.hard_reject_payload = nil

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
    assert_not OidcCallbackTestController.last_login_kwargs.fetch(:bootstrap_actor, false)
    assert OidcCallbackTestController.last_login_kwargs.fetch(:skip_login_cooldown)
  end

  test "show consumes the matching pending flow instead of the latest legacy flow" do
    get "/oidc/callback/session",
        params: {
          code_verifier: "newer-verifier",
          state: "newer-state",
          nonce: "newer-nonce",
          pt: "/",
          pending_state: "older-state",
          pending_code_verifier: "older-verifier",
          pending_nonce: "older-nonce",
          pending_pt: "/settings?ri=jp",
        }

    result = Result.new(
      success?: true,
      token_response: { access_token: "access", refresh_token: "refresh", id_token: "id-token" },
      error: nil,
      error_description: nil,
    )
    id_token_result = Struct.new(:success?, :payload, :error, keyword_init: true).new(
      success?: true,
      payload: { "sub" => "42", "nonce" => "older-nonce" },
      error: nil,
    )
    token_call = nil

    OidcRpTokenClient.stub(:call, ->(**kwargs) { token_call = kwargs; result }) do
      OidcIdTokenVerifier.stub(:call, id_token_result) do
        get "/oidc/callback", params: { code: "abc", state: "older-state" }
      end
    end

    assert_response :redirect
    assert_redirected_to "/settings?ri=jp"
    assert_equal "older-verifier", token_call.fetch(:code_verifier)
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

  test "show redirects session-limit pending callbacks to session management without restarting oidc" do
    get "/oidc/callback/session",
        params: { code_verifier: "verifier", state: "state", nonce: "nonce", pt: "/settings?ri=jp" }

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
    OidcCallbackTestController.login_result_for_test = {
      status: :success,
      session_management_required: true,
    }

    OidcRpTokenClient.stub(:call, result) do
      OidcIdTokenVerifier.stub(:call, id_token_result) do
        get "/oidc/callback", params: { code: "abc", state: "state" }
      end
    end

    assert_response :redirect
    assert_redirected_to "/sign/in/session"
    assert_equal "/settings?ri=jp", OidcCallbackTestController.last_session_limit_gate_pt
    assert OidcCallbackTestController.last_login_kwargs.fetch(:skip_login_cooldown)
    assert_not OidcCallbackTestController.last_login_kwargs.fetch(:bootstrap_actor, false)
  end

  test "show renders hard reject instead of restarting oidc when restricted session already exists" do
    get "/oidc/callback/session", params: { code_verifier: "verifier", state: "state", nonce: "nonce" }

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
    OidcCallbackTestController.login_result_for_test = {
      status: :session_limit_hard_reject,
      message: "too many sessions",
      http_status: :forbidden,
    }

    OidcRpTokenClient.stub(:call, result) do
      OidcIdTokenVerifier.stub(:call, id_token_result) do
        get "/oidc/callback", params: { code: "abc", state: "state" }
      end
    end

    assert_response :forbidden
    assert_equal "too many sessions", response.body
    assert_equal(
      { message: "too many sessions", http_status: :forbidden },
      OidcCallbackTestController.hard_reject_payload,
    )
  end

  test "show rejects mismatched state before token exchange" do
    get "/oidc/callback/session", params: { state: "expected" }
    logged = []

    OidcRpTokenClient.stub(:call, ->(**) { flunk("token exchange should not run for state mismatch") }) do
      Rails.logger.stub(
        :info, ->(message = nil, &block) {
                 message = block.call if message.nil? && block
                 logged << JSON.parse(message, symbolize_names: true) if message.to_s.start_with?("{")
               },
      ) do
        get "/oidc/callback", params: { code: "abc", state: "wrong" }
      end
    end

    assert_response :unprocessable_content
    event = logged.find { |entry| entry[:event] == "oidc.rp.callback.invalid_state" }

    assert_equal "OIDC state mismatch", event.dig(:data, :reason)
    assert event.dig(:data, :grant_present)
    assert event.dig(:data, :csrf_present)
    assert event.dig(:data, :expected_state_present)
    assert event.dig(:data, :actual_state_present)
    assert_predicate event.dig(:data, :expected_state_digest12), :present?
    assert_predicate event.dig(:data, :actual_state_digest12), :present?
    assert_not_equal "state", event.dig(:data, :expected_state_digest12)
    assert_not_equal "wrong", event.dig(:data, :actual_state_digest12)
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

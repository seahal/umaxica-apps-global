# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcCallbackTestController < ApplicationController
  def self.public_strict!
  end

  include Oidc::Callback

  def oidc_client_id
    "test-client-id"
  end

  def oidc_client_secret
    "test-client-secret"
  end

  def set_auth_cookies(**)
  end
end

# rubocop:disable Rails/ActionControllerTestCase
class Oidc::CallbackTest < ActionController::TestCase
  tests OidcCallbackTestController
  # rubocop:enable Rails/ActionControllerTestCase

  setup do
    @routes = Rails.application.routes
    Rails.application.routes.draw do
      get "/oidc/callback" => "oidc_callback_test#show"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  Result = Struct.new(:success?, :token_response, :error, :error_description, keyword_init: true)

  test "show redirects to return_to on successful exchange" do
    @request.session[:oidc_code_verifier] = "verifier"
    @request.session[:oidc_state] = "state"
    @request.session[:oidc_return_to] = "/after"

    result = Result.new(
      success?: true,
      token_response: { access_token: "access", refresh_token: "refresh" },
      error: nil,
      error_description: nil,
    )

    Oidc::TokenExchangeService.stub(:call, result) do
      get :show, params: { code: "abc", state: "state" }
    end

    assert_response :redirect
    assert_redirected_to "/after"
  end

  test "show redirects to root on failed exchange" do
    @request.session[:oidc_code_verifier] = "verifier"
    @request.session[:oidc_state] = "state"

    result = Result.new(
      success?: false,
      token_response: nil,
      error: "bad",
      error_description: "bad",
    )
    notifications = []

    Oidc::TokenExchangeService.stub(:call, result) do
      Rails.event.stub(:notify, ->(*args) { notifications << args }) do
        get :show, params: { code: "abc", state: "state" }
      end
    end

    assert_response :redirect
    assert_redirected_to "/"
    assert_equal 1, notifications.count { |args| args.first == "oidc.callback.failed" }
  end

  test "show raises when state does not match" do
    @request.session[:oidc_state] = "expected"

    assert_raises(ActionController::InvalidCrossOriginRequest) do
      get :show, params: { code: "abc", state: "wrong" }
    end
  end

  test "default oidc_client_id raises NotImplementedError" do
    # create a dummy controller without overriding
    dummy_class =
      Class.new(ApplicationController) do
        define_singleton_method(:public_strict!) do
          # No-op for test
        end
        include Oidc::Callback
      end

    assert_raises(NotImplementedError) do
      dummy_class.new.send(:oidc_client_id)
    end
  end

  test "oidc_client_secret uses ClientRegistry" do
    dummy_class =
      Class.new(ApplicationController) do
        define_singleton_method(:public_strict!) do
          # No-op for test
        end
        include Oidc::Callback

        define_method(:oidc_client_id) do
     "test-client"; end
      end

    client_mock = Struct.new(:client_secret).new("mock_secret")

    Oidc::ClientRegistry.stub(:find, client_mock) do
      assert_equal "mock_secret", dummy_class.new.send(:oidc_client_secret)
    end
  end
end

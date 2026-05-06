# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcSsoInitiatorTestController < ApplicationController
  include Oidc::SsoInitiator

  def index
    authenticate!
    head :ok unless performed?
  end

  def logged_in?
    request.headers["X-Logged-In"] == "1"
  end

  def current_resource
    Struct.new(:id).new(42)
  end

  def oidc_client_id
    "test-client-id"
  end
end

class Oidc::SsoInitiatorTest < ActionDispatch::IntegrationTest
  setup do
    Rails.application.routes.draw do
      get "/oidc/sso" => "oidc_sso_initiator_test#index"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "authenticate! redirects unauthenticated html requests to oidc authorize url" do
    get "/oidc/sso"

    assert_response :redirect
    assert_match %r{\Ahttp://id\.app\.localhost/authorize\?}, response.location
    assert_match %r{/auth/callback\z}, CGI.unescape(response.location[/redirect_uri=([^&]+)/, 1])
    assert_predicate session[:oidc_code_verifier], :present?
    assert_predicate session[:oidc_state], :present?
    assert_equal "http://www.example.com/oidc/sso", session[:oidc_return_to]
  end

  test "authenticate! renders unauthorized json for unauthenticated json requests" do
    get "/oidc/sso", as: :json

    assert_response :unauthorized
    assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
  end

  test "authenticate! calls risk enforcer for logged in users" do
    called = false

    Sign::Risk::Enforcer.stub(:call, ->(_resource) { called = true }) do
      get "/oidc/sso", headers: { "X-Logged-In" => "1" }
    end

    assert_response :ok
    assert called
  end
end

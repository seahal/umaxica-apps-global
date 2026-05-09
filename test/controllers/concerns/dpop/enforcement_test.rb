# typed: false
# frozen_string_literal: true

require "test_helper"

class DpopEnforcementDummyController < ApplicationController
  def self.public_strict!
  end

  include Dpop::Enforcement

  protect_from_forgery with: :null_session

  def current_resource_type
    "user"
  end

  def show
    render json: { ok: true }
  end
end

class Dpop::EnforcementTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @ec = OpenSSL::PKey::EC.generate("prime256v1")
    @jwk = JWT::JWK.new(@ec).export
    @host = "id.app.localhost"
    @request_uri = "http://#{@host}/dpop_test"
  end

  test "allows request without Authorization header" do
    with_dpop_route do
      get "/dpop_test", headers: { "Host" => @host }

      assert_response :ok
    end
  end

  test "allows Bearer request without DPoP header" do
    with_dpop_route do
      get "/dpop_test", headers: { "Host" => @host, "Authorization" => "Bearer sometoken" }

      assert_response :ok
    end
  end

  test "rejects Bearer request when DPoP header is also present" do
    with_dpop_route do
      get "/dpop_test", headers: {
        "Host" => @host,
        "Authorization" => "Bearer sometoken",
        "DPoP" => "someproof",
      }

      assert_response :unauthorized
      body = response.parsed_body

      assert_equal "invalid_token", body["error"]
    end
  end

  test "rejects DPoP request when access token cannot be decoded" do
    with_dpop_route do
      proof = build_dpop_proof(method: "GET", uri: @request_uri)

      get "/dpop_test", headers: {
        "Host" => @host,
        "Authorization" => "DPoP not.a.valid.token",
        "DPoP" => proof,
      }

      assert_response :unauthorized
      body = response.parsed_body

      assert_equal "invalid_token", body["error"]
    end
  end

  test "rejects DPoP request when proof is invalid" do
    access_token = issue_dpop_access_token
    with_dpop_route do
      get "/dpop_test", headers: {
        "Host" => @host,
        "Authorization" => "DPoP #{access_token}",
        "DPoP" => "not.a.valid.proof",
      }

      assert_response :unauthorized
      body = response.parsed_body

      assert_equal "invalid_dpop_proof", body["error"]
    end
  end

  test "issues DPoP-Nonce header on proof failure" do
    access_token = issue_dpop_access_token
    with_dpop_route do
      get "/dpop_test", headers: {
        "Host" => @host,
        "Authorization" => "DPoP #{access_token}",
        "DPoP" => "not.a.valid.proof",
      }

      assert_response :unauthorized
      assert_predicate response.headers["DPoP-Nonce"], :present?
    end
  end

  test "allows valid DPoP request with matching proof" do
    access_token = issue_dpop_access_token
    proof = build_dpop_proof(method: "GET", uri: @request_uri, access_token: access_token)

    with_dpop_route do
      get "/dpop_test", headers: {
        "Host" => @host,
        "Authorization" => "DPoP #{access_token}",
        "DPoP" => proof,
      }

      assert_response :ok
    end
  end

  test "rejects DPoP request when jkt does not match proof key" do
    # Issue token with one key, present proof with a different key
    access_token = issue_dpop_access_token

    other_ec = OpenSSL::PKey::EC.generate("prime256v1")
    other_jwk = JWT::JWK.new(other_ec).export
    proof = build_dpop_proof(
      method: "GET", uri: @request_uri, access_token: access_token,
      private_key: other_ec, jwk: other_jwk,
    )

    with_dpop_route do
      get "/dpop_test", headers: {
        "Host" => @host,
        "Authorization" => "DPoP #{access_token}",
        "DPoP" => proof,
      }

      assert_response :unauthorized
    end
  end

  private

  def issue_dpop_access_token
    jkt = Jit::Security::Jwt::ThumbprintCalculator.calculate(@jwk)
    Auth::TokenService.encode(
      @user,
      host: @host,
      resource_type: "user",
      dpop_jkt: jkt,
      session_public_id: "test-session-id",
    )
  end

  def build_dpop_proof(method:, uri:, access_token: nil, private_key: nil, jwk: nil)
    pk = private_key || @ec
    jwk_val = jwk || @jwk
    payload = {
      "htm" => method,
      "htu" => uri,
      "iat" => Time.current.to_i,
      "jti" => SecureRandom.uuid,
    }
    if access_token.present?
      payload["ath"] = Jit::Security::Jwt::ThumbprintCalculator.ath(access_token)
    end
    JWT.encode(payload, pk, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk_val })
  end

  def with_dpop_route(&block)
    with_routing do |set|
      set.draw do
        get("/dpop_test", to: "dpop_enforcement_dummy#show")
      end
      block.call
    end
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::TokensControllerTest < ActionDispatch::IntegrationTest
  Result = Struct.new(:success?, :token_response, :error, :error_description, keyword_init: true)

  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
  end

  test "create returns token response on success" do
    result = Result.new(success?: true, token_response: { access_token: "access", refresh_token: "refresh" })

    Oidc::TokenExchangeService.stub(:call, result) do
      post sign_com_token_url,
           params: {
             grant_type: "authorization_code",
             code: "abc",
             redirect_uri: "http://example.com/callback",
             client_id: "client-id",
             client_secret: "secret",
             code_verifier: "verifier",
           },
           headers: { "Host" => @host }
    end

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "no-cache", response.headers["Pragma"]
    assert_equal "access", response.parsed_body["access_token"]
  end

  test "create returns bad request on failure" do
    result = Result.new(success?: false, token_response: nil, error: "bad", error_description: "bad")

    Oidc::TokenExchangeService.stub(:call, result) do
      post sign_com_token_url,
           params: {
             grant_type: "authorization_code",
             code: "abc",
             redirect_uri: "http://example.com/callback",
             client_id: "client-id",
             client_secret: "secret",
             code_verifier: "verifier",
           },
           headers: { "Host" => @host }
    end

    assert_response :bad_request
    assert_equal "bad", response.parsed_body["error"]
  end
end

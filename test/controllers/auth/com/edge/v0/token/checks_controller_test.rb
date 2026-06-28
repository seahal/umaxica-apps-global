# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/auth_helpers"

class Auth::Com::Edge::V0::Token::ChecksControllerTest < ActionDispatch::IntegrationTest
  fixtures :visitors

  setup do
    @visitor = visitors(:reserved_visitor)
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
  end

  test "GET check without access token returns 401" do
    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    assert_not response.parsed_body["authenticated"]
  end

  test "GET check with a valid JWT access token returns 200" do
    token_record = VisitorToken.create!(visitor: @visitor)
    token_record.rotate_refresh_token!

    access_token = jwt_access_token_for(
      @visitor,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "visitor",
    )

    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :ok
    json = response.parsed_body

    assert json["authenticated"]
    assert_equal "visitor", json["type"]
    assert_equal @visitor.id, json["id"]
    assert_equal token_record.device_session.public_id, json["sid"]
  end
end

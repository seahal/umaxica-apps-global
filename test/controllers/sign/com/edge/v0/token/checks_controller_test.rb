# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Edge::V0::Token::ChecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
  end

  test "GET check without access token returns 401" do
    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    assert_not response.parsed_body["authenticated"]
  end
end

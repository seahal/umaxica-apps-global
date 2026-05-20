# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Com
    class JwksControllerTest < ActionDispatch::IntegrationTest
      test "GET jwks endpoint returns JSON with keys" do
        host! "id.com.localhost"
        get sign_com_oauth_jwks_url(ri: "jp")

        assert_response :success
        assert_equal "application/json", response.media_type
        assert_includes response.parsed_body.keys, "keys"
      end
    end
  end
end

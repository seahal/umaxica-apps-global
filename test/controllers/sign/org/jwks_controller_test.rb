# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  module Org
    class JwksControllerTest < ActionDispatch::IntegrationTest
      test "GET jwks endpoint returns JSON with keys" do
        host! "id.org.localhost"
        get sign_org_jwks_url(ri: "jp")

        assert_response :success
        assert_equal "application/json", response.media_type
        body = response.parsed_body

        assert_includes body.keys, "keys"
      end
    end
  end
end

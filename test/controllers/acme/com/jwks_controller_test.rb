# typed: false
# frozen_string_literal: true

require "test_helper"

module Acme
  module Com
    class JwksControllerTest < ActionDispatch::IntegrationTest
      fixtures_none!

      test "GET jwks endpoint returns JSON with keys" do
        host! ENV.fetch("ACME_CORPORATE_URL", "com.localhost")

        get acme_com_jwks_url

        assert_response :success
        assert_equal "application/json", response.media_type
        assert_includes response.parsed_body.keys, "keys"
      end
    end
  end
end

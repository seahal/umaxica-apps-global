# typed: false
# frozen_string_literal: true

require "test_helper"

module Base
  module App
    class JwksControllerTest < ActionDispatch::IntegrationTest
      self.fixture_table_names = []

      test "GET jwks endpoint returns JSON with keys" do
        host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")

        get base_app_well_known_jwks_url

        assert_response :success
        assert_equal "application/json", response.media_type
        assert_includes response.parsed_body.keys, "keys"
      end
    end
  end
end

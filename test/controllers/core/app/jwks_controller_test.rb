# typed: false
# frozen_string_literal: true

require "test_helper"

module Core
  module App
    class JwksControllerTest < ActionDispatch::IntegrationTest
      fixtures_none!

      test "GET jwks endpoint returns JSON with keys" do
        host! ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"))

        get core_app_well_known_jwks_url

        assert_response :success
        assert_equal "application/json", response.media_type
        assert_includes response.parsed_body.keys, "keys"
      end
    end
  end
end

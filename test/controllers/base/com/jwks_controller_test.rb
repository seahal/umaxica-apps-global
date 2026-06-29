# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

module Base
  module Com
    class JwksControllerTest < ActionDispatch::IntegrationTest
      self.fixture_table_names = []

      test "GET jwks endpoint returns JSON with keys" do
        host! ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost")

        get base_com_well_known_jwks_url

        assert_response :success
        assert_equal "application/json", response.media_type
        assert_includes response.parsed_body.keys, "keys"
      end
    end
  end
end

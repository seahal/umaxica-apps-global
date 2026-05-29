# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  class TokenCsrfTest < ActionDispatch::IntegrationTest
    fixtures_none!

    test "app token endpoint rejects missing csrf token" do
      host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

      with_forgery_protection do
        post sign_app_oauth_token_path, params: { grant_type: "authorization_code" }

        assert_response :bad_request
        assert_equal "invalid_request", response.parsed_body.fetch("error")
        assert_equal "OIDC client authentication failed", response.parsed_body.fetch("error_description")
      end
    end

    test "com token endpoint rejects missing csrf token" do
      host! ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")

      with_forgery_protection do
        post sign_com_oauth_token_path, params: { grant_type: "authorization_code" }

        assert_response :bad_request
        assert_equal "invalid_request", response.parsed_body.fetch("error")
        assert_equal "OIDC client authentication failed", response.parsed_body.fetch("error_description")
      end
    end

    test "org token endpoint rejects missing csrf token" do
      host! ENV.fetch("SIGN_STAFF_URL", "id.org.localhost")

      with_forgery_protection do
        post sign_org_oauth_token_path, params: { grant_type: "authorization_code" }

        assert_response :bad_request
        assert_equal "invalid_request", response.parsed_body.fetch("error")
        assert_equal "OIDC client authentication failed", response.parsed_body.fetch("error_description")
      end
    end
  end
end

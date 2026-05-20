# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign
  class TokenCsrfTest < ActionDispatch::IntegrationTest
    fixtures_none!

    test "app token endpoint rejects missing csrf token" do
      host! ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")

      with_forgery_protection do
        post sign_app_oauth_token_path

        assert_response :unprocessable_content
      end
    end

    test "com token endpoint rejects missing csrf token" do
      host! ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")

      with_forgery_protection do
        post sign_com_oauth_token_path

        assert_response :unprocessable_content
      end
    end

    test "org token endpoint rejects missing csrf token" do
      host! ENV.fetch("SIGN_STAFF_URL", "id.org.localhost")

      with_forgery_protection do
        post sign_org_oauth_token_path

        assert_response :unprocessable_content
      end
    end
  end
end

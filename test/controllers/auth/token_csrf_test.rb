# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::TokenCsrfTest < ActionDispatch::IntegrationTest
  test "sign oauth token routes are retired instead of csrf-exempt provider endpoints" do
    {
      ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost") => "/oauth/token",
      ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost") => "/oauth/token",
      ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost") => "/oauth/token",
    }.each do |host, path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("https://#{host}#{path}", method: :post)
      end
    end
  end
end

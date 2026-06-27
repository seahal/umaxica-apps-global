# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::TokenCsrfTest < ActionDispatch::IntegrationTest
  test "sign oauth token routes are retired instead of csrf-exempt provider endpoints" do
    {
      ENV.fetch("ID_SERVICE_URL", "id.app.localhost") => "/oauth/token",
      ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost") => "/oauth/token",
      ENV.fetch("ID_STAFF_URL", "id.org.localhost") => "/oauth/token",
    }.each do |host, path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("https://#{host}#{path}", method: :post)
      end
    end
  end
end

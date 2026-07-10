# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Com::TokensControllerTest < ActionDispatch::IntegrationTest
  test "sign com oauth token route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")}/oauth/token",
        method: :post,
      )
    end
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Com::AuthorizesControllerTest < ActionDispatch::IntegrationTest
  test "sign com oauth authorize route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")}/oauth/authorize",
        method: :get,
      )
    end
  end
end

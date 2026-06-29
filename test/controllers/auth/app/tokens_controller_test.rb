# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::App::TokensControllerTest < ActionDispatch::IntegrationTest
  test "sign app oauth token route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")}/oauth/token",
        method: :post,
      )
    end
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Edge::V0::Token::RefreshesControllerTest < ActionDispatch::IntegrationTest
  test "sign app refresh route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")}/edge/v0/token/refresh",
        method: :post,
      )
    end
  end
end

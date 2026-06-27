# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Edge::V0::Token::RefreshesControllerTest < ActionDispatch::IntegrationTest
  test "sign app refresh route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_SERVICE_URL", "id.app.localhost")}/edge/v0/token/refresh",
        method: :post,
      )
    end
  end
end

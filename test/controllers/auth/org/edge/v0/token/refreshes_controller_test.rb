# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Edge::V0::Token::RefreshesControllerTest < ActionDispatch::IntegrationTest
  test "sign org refresh route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")}/edge/v0/token/refresh",
        method: :post,
      )
    end
  end
end

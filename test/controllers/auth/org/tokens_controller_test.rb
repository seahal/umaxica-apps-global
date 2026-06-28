# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::TokensControllerTest < ActionDispatch::IntegrationTest
  test "sign org oauth token route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("AUTH_STAFF_URL", "auth.org.localhost")}/oauth/token",
        method: :post,
      )
    end
  end
end

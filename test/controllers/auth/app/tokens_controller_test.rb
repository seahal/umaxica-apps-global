# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::TokensControllerTest < ActionDispatch::IntegrationTest
  test "sign app oauth token route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("AUTH_SERVICE_URL")}/oauth/token",
        method: :post,
      )
    end
  end
end

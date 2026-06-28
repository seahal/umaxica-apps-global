# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::TokensControllerTest < ActionDispatch::IntegrationTest
  test "sign com oauth token route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("AUTH_CORPORATE_URL")}/oauth/token",
        method: :post,
      )
    end
  end
end

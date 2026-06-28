# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::AuthorizesControllerTest < ActionDispatch::IntegrationTest
  test "sign app oauth authorize route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("AUTH_SERVICE_URL")}/oauth/authorize",
        method: :get,
      )
    end
  end
end

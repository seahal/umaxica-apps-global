# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::AuthorizesControllerTest < ActionDispatch::IntegrationTest
  test "sign org oauth authorize route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("AUTH_STAFF_URL")}/oauth/authorize",
        method: :get,
      )
    end
  end
end

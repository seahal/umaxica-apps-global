# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::AuthorizesControllerTest < ActionDispatch::IntegrationTest
  test "sign app oauth authorize route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_SERVICE_URL", "id.app.localhost")}/oauth/authorize",
        method: :get,
      )
    end
  end
end

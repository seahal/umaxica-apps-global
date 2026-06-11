# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::TokensControllerTest < ActionDispatch::IntegrationTest
  test "sign app oauth token route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_SERVICE_URL", "id.app.localhost")}/oauth/token",
        method: :post,
      )
    end
  end
end

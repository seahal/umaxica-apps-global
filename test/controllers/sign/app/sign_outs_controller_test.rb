# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::SignOutsControllerTest < ActionDispatch::IntegrationTest
  test "sign app sign-out ceremony routes are retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_SERVICE_URL", "id.app.localhost")}/sign/out/confirmation",
        method: :get,
      )
    end
  end
end

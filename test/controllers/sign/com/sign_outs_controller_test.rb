# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::SignOutsControllerTest < ActionDispatch::IntegrationTest
  test "sign com sign-out ceremony routes are retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")}/sign/out/confirmation",
        method: :get,
      )
    end
  end
end

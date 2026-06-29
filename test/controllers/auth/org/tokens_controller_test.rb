# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::Org::TokensControllerTest < ActionDispatch::IntegrationTest
  test "sign org oauth token route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")}/oauth/token",
        method: :post,
      )
    end
  end
end

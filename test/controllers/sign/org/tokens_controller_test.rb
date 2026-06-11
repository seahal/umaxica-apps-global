# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::TokensControllerTest < ActionDispatch::IntegrationTest
  test "sign org oauth token route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_STAFF_URL", "id.org.localhost")}/oauth/token",
        method: :post,
      )
    end
  end
end

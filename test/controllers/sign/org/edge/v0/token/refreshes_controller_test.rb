# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Edge::V0::Token::RefreshesControllerTest < ActionDispatch::IntegrationTest
  test "sign org refresh route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_STAFF_URL", "id.org.localhost")}/edge/v0/token/refresh",
        method: :post,
      )
    end
  end
end

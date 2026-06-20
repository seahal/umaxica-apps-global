# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Edge::V0::Token::RefreshesControllerTest < ActionDispatch::IntegrationTest
  test "sign com refresh route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")}/edge/v0/token/refresh",
        method: :post,
      )
    end
  end
end

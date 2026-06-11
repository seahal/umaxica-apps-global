# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::TokensControllerTest < ActionDispatch::IntegrationTest
  test "sign com oauth token route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")}/oauth/token",
        method: :post,
      )
    end
  end
end

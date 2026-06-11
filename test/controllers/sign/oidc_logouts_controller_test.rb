# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::OidcLogoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
  end

  test "sign oidc logout route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{@host}/oidc/logout", method: :get)
    end
  end
end

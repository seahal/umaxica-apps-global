# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::OidcLogoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
  end

  test "sign oidc logout route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{@host}/oidc/logout", method: :get)
    end
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::JwksControllerTest < ActionDispatch::IntegrationTest
  test "sign app well-known jwks remains public" do
    get auth_app_well_known_jwks_url(host: ENV.fetch("AUTH_SERVICE_URL", "auth.app.localhost"), ri: "jp")

    assert_response :ok
    assert_predicate response.parsed_body.fetch("keys"), :present?
  end

  test "sign app oauth jwks route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("AUTH_SERVICE_URL", "auth.app.localhost")}/oauth/jwks",
        method: :get,
      )
    end
  end
end

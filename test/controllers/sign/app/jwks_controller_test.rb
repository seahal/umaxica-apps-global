# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::JwksControllerTest < ActionDispatch::IntegrationTest
  test "sign app well-known jwks remains public" do
    get sign_app_jwks_url(host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"), ri: "jp")

    assert_response :ok
    assert_predicate response.parsed_body.fetch("keys"), :present?
  end

  test "sign app oauth jwks route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_SERVICE_URL", "id.app.localhost")}/oauth/jwks",
        method: :get,
      )
    end
  end
end

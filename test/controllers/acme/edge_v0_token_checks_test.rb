# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/auth_helpers"

class Acme::EdgeV0TokenChecksTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :visitors

  SURFACES = [
    {
      host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      actor: ->(test_case) { test_case.clients(:one) },
      build_token: ->(test_case) { ClientToken.create!(user: test_case.clients(:one)) },
      resource_type: "client",
    },
    {
      host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
      actor: ->(test_case) { test_case.operators(:one) },
      build_token: ->(test_case) { OperatorToken.create!(staff: test_case.operators(:one)) },
      resource_type: "operator",
    },
  ].freeze

  test "GET check without an access token returns 401 on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      get "/edge/v0/token/check",
          headers: { "Host" => host, "Accept" => "application/json" },
          as: :json

      assert_response :unauthorized
      assert_equal({ "authenticated" => false }, response.parsed_body)
    end
  end
end

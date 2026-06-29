# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::EdgeV0TokenRefreshesTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :visitors

  SURFACES = [
    {
      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      build_token: ->(test_case) { ClientToken.create!(user: test_case.clients(:one)) },
    },
    {
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
      build_token: ->(test_case) { VisitorToken.create!(visitor: test_case.visitors(:reserved_visitor)) },
    },
    {
      host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      build_token: ->(test_case) { OperatorToken.create!(staff: test_case.operators(:one)) },
    },
  ].freeze

  test "POST refresh without a refresh token returns a validation error on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      post "/edge/v0/token/refresh",
           headers: { "Host" => host, "Accept" => "application/json" },
           as: :json

      assert_response :bad_request
      assert_equal "missing_refresh_token", response.parsed_body.fetch("error_code")
    end
  end

  test "POST refresh with a valid cookie refresh token succeeds on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      token_record = surface.fetch(:build_token).call(self)
      refresh_plain = token_record.rotate_refresh_token!

      host! host

      post "/edge/v0/token/refresh",
           params: { refresh_token: refresh_plain },
           headers: { "Host" => host, "Accept" => "application/json" },
           as: :json

      assert_response :success
      assert response.parsed_body["refreshed"]
    end
  end

  test "POST refresh with an invalid refresh token returns a structured error on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      post "/edge/v0/token/refresh",
           params: { refresh_token: "bogus-refresh-token" },
           headers: { "Host" => host, "Accept" => "application/json" },
           as: :json

      assert_response :unauthorized
      assert_equal "invalid_refresh_token", response.parsed_body.fetch("error_code")
    end
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/auth_helpers"

# Surface boundary: an access token minted for one surface (app/com/org) must
# never authenticate on another surface's endpoint, even though every surface
# exposes the same `/edge/v0/token/check` path. The binding is enforced by the
# per-surface JWT issuer/audience, not by sharing a DB. These tests pin that
# boundary symmetrically: each token is proven valid on its own surface
# (control) and rejected on the foreign surface.
class CrossSurfaceTokenTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators

  CHECK_PATH = "/edge/v0/token/check"

  setup do
    @app_host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    @org_host = ENV.fetch("PRIVATE_AUTH_STAFF_URL")
    @user = clients(:one)
    @staff = operators(:one)
    ClientToken.where(user: @user).delete_all
    OperatorToken.where(staff: @staff).delete_all
  end

  test "app client access token authenticates on the app surface (control)" do
    token = bearer_for_client

    get CHECK_PATH, headers: json_headers(@app_host, token), as: :json

    assert_response :ok
    assert response.parsed_body["authenticated"], "app token must authenticate on the app surface"
    assert_equal "client", response.parsed_body["type"]
  end

  test "app client access token is rejected by the org surface check endpoint" do
    token = bearer_for_client

    get CHECK_PATH, headers: json_headers(@org_host, token), as: :json

    assert_response :unauthorized
    assert_not response.parsed_body["authenticated"],
               "app-issued token must not authenticate on the org surface"
  end

  test "org operator access token authenticates on the org surface (control)" do
    token = bearer_for_operator

    get CHECK_PATH, headers: json_headers(@org_host, token), as: :json

    assert_response :ok
    assert response.parsed_body["authenticated"], "org token must authenticate on the org surface"
    assert_equal "operator", response.parsed_body["type"]
  end

  test "org operator access token is rejected by the app surface check endpoint" do
    token = bearer_for_operator

    get CHECK_PATH, headers: json_headers(@app_host, token), as: :json

    assert_response :unauthorized
    assert_not response.parsed_body["authenticated"],
               "org-issued token must not authenticate on the app surface"
  end

  private

  def json_headers(host, bearer_token)
    {
      "Host" => host,
      "Accept" => "application/json",
      "Authorization" => "Bearer #{bearer_token}",
    }
  end

  def bearer_for_client
    record = ClientToken.create!(user: @user)
    record.rotate_refresh_token!
    jwt_access_token_for(
      @user,
      host: @app_host,
      session_public_id: record.public_id,
      resource_type: "client",
    )
  end

  def bearer_for_operator
    record = OperatorToken.create!(staff: @staff)
    record.rotate_refresh_token!
    jwt_access_token_for(
      @staff,
      host: @org_host,
      session_public_id: record.public_id,
      resource_type: "operator",
    )
  end
end

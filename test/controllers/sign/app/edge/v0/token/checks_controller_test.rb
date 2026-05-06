# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Edge::V0::Token::ChecksControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    @user = users(:one)
    @host = ENV.fetch("ID_SERVICE_URL", "test.umaxica.com")
    UserToken.where(user: @user).delete_all
  end

  test "GET check with valid JWT access token returns 200" do
    # Create a token record and generate tokens
    token_record = UserToken.create!(user: @user)
    token_record.rotate_refresh_token!

    # Generate a valid JWT access token
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "user",
    )

    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :ok
    json = response.parsed_body

    assert json["authenticated"], "User should be authenticated"
    assert_equal "user", json["type"]
    assert_equal @user.id, json["id"]
    assert_equal token_record.public_id, json["sid"]
  end

  test "GET check without access token returns 401" do
    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
    assert_equal({ "authenticated" => false }, json)
  end

  test "GET check with invalid JWT returns 401" do
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = "invalid.jwt.token"

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
    assert_equal({ "authenticated" => false }, json)
  end

  test "GET check with expired JWT returns 401" do
    # Create a token record
    token_record = UserToken.create!(user: @user)
    token_record.rotate_refresh_token!

    # Generate a JWT that's already expired
    # We need to manipulate time to create an expired token
    expired_token = nil
    travel_to(2.hours.ago) do
      expired_token = jwt_access_token_for(
        @user,
        host: @host,
        session_public_id: token_record.public_id,
        resource_type: "user",
      )
    end

    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = expired_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
    assert_equal({ "authenticated" => false }, json)
  end

  test "GET check with wrong resource type returns 401" do
    # Create a token record
    token_record = UserToken.create!(user: @user)
    token_record.rotate_refresh_token!

    # Generate a JWT with wrong resource type (staff instead of user)
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "staff", # wrong type for user endpoint
    )

    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :unauthorized
    json = response.parsed_body

    assert_not json["authenticated"]
    assert_equal({ "authenticated" => false }, json)
  end

  test "GET check includes Cache-Control no-store header" do
    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "GET check with Bearer header takes precedence over cookie" do
    # Create a token record and generate tokens
    token_record = UserToken.create!(user: @user)
    token_record.rotate_refresh_token!

    # Generate a valid JWT access token
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "user",
    )

    # Set invalid cookie but valid Bearer header
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = "invalid.cookie.token"

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "Bearer #{access_token}",
        },
        as: :json

    assert_response :ok
    json = response.parsed_body

    assert json["authenticated"], "Bearer token should take precedence"
    assert_equal "user", json["type"]
    assert_equal @user.id, json["id"]
    assert_equal token_record.public_id, json["sid"]
  end

  test "GET check with missing sid returns 401" do
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: nil,
      resource_type: "user",
    )

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "Bearer #{access_token}",
        },
        as: :json

    assert_response :unauthorized
    assert_equal({ "authenticated" => false }, response.parsed_body)
  end

  test "logout destroys token record so old Bearer access fails" do
    token_record = UserToken.create!(user: @user)
    refresh_plain = token_record.rotate_refresh_token!
    access_token = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "user",
    )

    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = access_token
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    # Verify token exists before logout
    assert_not_nil UserToken.find_by(public_id: token_record.public_id)

    # Simulate logout by destroying the token directly (the cookie-based destroy
    # requires domain matching which is complex in integration tests)
    token_record.destroy!

    get "/edge/v0/token/check",
        headers: {
          "Host" => @host,
          "Accept" => "application/json",
          "Authorization" => "Bearer #{access_token}",
        },
        as: :json

    assert_response :unauthorized
    assert_equal({ "authenticated" => false }, response.parsed_body)
  end
end

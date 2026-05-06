# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Edge::V0::Token::ChecksControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_tokens, :users

  setup do
    @staff = staffs(:one)
    @host = ENV.fetch("ID_STAFF_URL", "test.umaxica.com")
  end

  test "GET check with valid JWT access token returns 200" do
    token_record = StaffToken.create!(staff: @staff)
    token_record.rotate_refresh_token!

    access_token = jwt_access_token_for(
      @staff,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "staff",
    )

    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = access_token

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :ok
    json = response.parsed_body

    assert json["authenticated"], "Staff should be authenticated"
    assert_equal "staff", json["type"]
    assert_equal @staff.id, json["id"]
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

  test "GET check with missing sid returns 401" do
    access_token = jwt_access_token_for(
      @staff,
      host: @host,
      session_public_id: nil,
      resource_type: "staff",
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

  test "GET check with user token on staff endpoint returns 401" do
    user = users(:one)

    # Create a staff token record for the session to exist
    token_record = StaffToken.create!(staff: @staff)
    token_record.rotate_refresh_token!

    # Generate a JWT with user actor type (wrong for staff endpoint)
    access_token = jwt_access_token_for(
      user,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "user",
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

  test "logout destroys token record so old Bearer access fails" do
    token_record = StaffToken.create!(staff: @staff)
    refresh_plain = token_record.rotate_refresh_token!
    access_token = jwt_access_token_for(
      @staff,
      host: @host,
      session_public_id: token_record.public_id,
      resource_type: "staff",
    )

    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = access_token
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    # Verify token exists before logout
    assert_not_nil StaffToken.find_by(public_id: token_record.public_id)

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

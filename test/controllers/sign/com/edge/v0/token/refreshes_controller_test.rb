# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Edge::V0::Token::RefreshesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @csrf_token = "test_csrf_token"
    setup_visitor_token_references
    @visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
  end

  test "POST refresh with valid visitor refresh token sets access and refresh cookies" do
    token_record = VisitorToken.create!(visitor: @visitor)
    refresh_plain = token_record.rotate_refresh_token!

    cookies["csrf_token"] = @csrf_token
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers,
         as: :json

    assert_response :ok
    assert response_has_cookie?(Authentication::Base::ACCESS_COOKIE_KEY)
    assert response_has_cookie?(Authentication::Base::REFRESH_COOKIE_KEY)
    assert response.parsed_body["refreshed"]
  end

  test "GET check with valid visitor access token from refresh returns 200" do
    token_record = VisitorToken.create!(visitor: @visitor)
    refresh_plain = token_record.rotate_refresh_token!

    cookies["csrf_token"] = @csrf_token
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers,
         as: :json

    assert_response :ok

    response_cookies = extract_cookies_from_response
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = response_cookies[Authentication::Base::ACCESS_COOKIE_KEY]

    get "/edge/v0/token/check",
        headers: { "Host" => @host, "Accept" => "application/json" },
        as: :json

    assert_response :ok
    assert response.parsed_body["authenticated"]
    assert_equal "visitor", response.parsed_body["type"]
  end

  test "POST refresh with restricted visitor token returns localized error" do
    token_record = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_status_id: VisitorTokenStatus::RESTRICTED,
    )
    refresh_plain = token_record.rotate_refresh_token!(discarded_at: 15.minutes.from_now)

    cookies["csrf_token"] = @csrf_token
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain

    post "/edge/v0/token/refresh",
         headers: json_headers,
         as: :json

    assert_response :forbidden
    assert_equal "restricted_session", response.parsed_body["error_code"]
  end

  private

  def json_headers
    {
      "Host" => @host,
      "Accept" => "application/json",
      "X-CSRF-Token" => @csrf_token,
    }
  end

  def setup_visitor_token_references
    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenStatus.ensure_defaults!
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end
end

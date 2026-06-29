# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::App::IdentityAuthoritySlice1ATest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @user = clients(:one)
  end

  test "base_sign_out_create_is_session_mutation_and_redirects_to_sign_handoff" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post base_app_sign_out_url(ri: "jp"), headers: session_headers(token)

    assert_response :see_other
    assert_predicate token.reload, :revoked?
    location = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), location.host
    assert_equal "/sign/out", location.path
    assert_predicate Rack::Utils.parse_nested_query(location.query.to_s)["logout_token"], :present?
  end

  private

  def session_headers(token, user: @user, host: @host)
    {
      "Host" => host,
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end

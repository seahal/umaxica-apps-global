# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Settings::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_statuses, :client_token_kinds

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = clients(:one)
    @current_token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "index_redirects_to_acme_session_authority" do
    get sign_app_settings_sessions_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_sessions
  end

  test "destroy_redirect_is_not_session_mutation" do
    other_token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    delete sign_app_settings_session_url(other_token.public_id, ri: "jp"), headers: session_headers

    assert_redirect_to_acme_sessions
    assert_predicate other_token.reload, :currently_usable?
  end

  test "others_redirect_is_not_session_inventory_mutation" do
    other_token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    delete sign_app_settings_session_revocations_others_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_sessions
    assert_predicate other_token.reload, :currently_usable?
  end

  test "revoke_all_redirect_is_not_session_mutation" do
    other_token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    delete sign_app_settings_session_revocations_all_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_sessions
    assert_predicate @current_token.reload, :currently_usable?
    assert_predicate other_token.reload, :currently_usable?
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @current_token.public_id,
    }
  end

  def assert_redirect_to_acme_sessions
    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal @acme_host, location.host
    assert_equal "/settings/sessions", location.path
    assert_equal "ri=jp", location.query
  end
end

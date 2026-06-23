# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::IdentityAuthoritySlice1ATest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = clients(:one)
  end

  test "acme_sign_out_create_is_session_mutation_and_renders_post_handoff" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post acme_app_sign_out_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_predicate token.reload, :revoked?
    form = css_select("form#sign-out-handoff-form").first
    location = URI.parse(form["action"])

    assert_equal ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost"), location.host
    assert_equal "/sign/out", location.path
    assert_predicate css_select('form#sign-out-handoff-form input[name="logout_challenge"]').first["value"],
                     :present?
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

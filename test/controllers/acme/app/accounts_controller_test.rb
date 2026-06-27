# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    @bootstrap = bootstrap_and_select!(@user, @token)
  end

  test "unauthenticated cannot access accounts" do
    get acme_app_accounts_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :redirect
    assert_oidc_authorize_redirect(response.location, host: @host)
  end

  test "index lists accounts" do
    get acme_app_accounts_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_select "body", text: /account/i
  end

  test "show resolves by public_id" do
    get acme_app_account_url(@bootstrap.account.public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_select "body", text: /account/i
  end

  test "unknown public_id returns 404" do
    get acme_app_account_url("unknown-account", ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :not_found
  end

  private

  def bootstrap_and_select!(user, token)
    result = AcmeSelectorBootstrapAuthority.call(surface: :app, principal: user)
    AcmeSelectorAuthority.prepare(surface: :app, principal: user, session: token)
    result
  end
end

# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "unauthenticated cannot access accounts" do
    get acme_app_accounts_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :redirect
    assert_match(%r{\Ahttps://jump\.umaxica\.net/\?rt=}, response.location)
  end

  test "selector-only (no selected context) cannot access accounts" do
    get acme_app_accounts_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    assert_match(%r{/selector}, response.location)
  end

  test "full login can list accounts" do
    bootstrap_and_select!(@user, @token)

    get acme_app_accounts_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :success
  end

  test "full login can show, edit and update own account" do
    result = bootstrap_and_select!(@user, @token)

    get acme_app_account_url(result.account.public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success

    get edit_acme_app_account_url(result.account.public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success

    patch acme_app_account_url(result.account.public_id, ri: "jp", host: @host),
          headers: as_user_headers(@user, host: @host)

    assert_response :see_other
  end

  test "new account form renders" do
    bootstrap_and_select!(@user, @token)

    get new_acme_app_account_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :success
  end

  test "cannot show another client's account" do
    bootstrap_and_select!(@user, @token)
    other_account = bootstrap_other_client.account

    get acme_app_account_url(other_account.public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :not_found
  end

  test "cannot update another client's account" do
    bootstrap_and_select!(@user, @token)
    other_account = bootstrap_other_client.account

    patch acme_app_account_url(other_account.public_id, ri: "jp", host: @host),
          headers: as_user_headers(@user, host: @host)

    assert_response :not_found
  end

  private

  def bootstrap_and_select!(user, token)
    result = AcmeSelectorBootstrapAuthority.call(surface: :app, principal: user)
    AcmeSelectorAuthority.prepare(surface: :app, principal: user, session: token)
    result
  end

  def bootstrap_other_client
    other = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    AcmeSelectorBootstrapAuthority.call(surface: :app, principal: other)
  end
end

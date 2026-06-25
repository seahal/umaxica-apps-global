# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "unauthenticated cannot access organizations" do
    get acme_app_organizations_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :redirect
    assert_oidc_authorize_redirect(response.location, host: @host)
  end

  test "selector-only (no selected context) cannot access organizations" do
    get acme_app_organizations_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    assert_match(%r{/selector}, response.location)
  end

  test "full login can list organizations" do
    bootstrap_and_select!(@user, @token)

    get acme_app_organizations_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :success
  end

  test "full login can show, edit and update own organization" do
    result = bootstrap_and_select!(@user, @token)

    get acme_app_organization_url(result.collective.public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success

    get edit_acme_app_organization_url(result.collective.public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success

    patch acme_app_organization_url(result.collective.public_id, ri: "jp", host: @host),
          headers: as_user_headers(@user, host: @host)

    assert_response :see_other
  end

  test "new organization form renders" do
    bootstrap_and_select!(@user, @token)

    get new_acme_app_organization_url(ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success
  end

  test "create organization redirects" do
    bootstrap_and_select!(@user, @token)

    post acme_app_organizations_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :see_other
    assert_redirected_to acme_app_organizations_url(ri: "jp", host: @host)
  end

  test "cannot show another client's organization" do
    bootstrap_and_select!(@user, @token)
    other_organization = bootstrap_other_client.collective

    get acme_app_organization_url(other_organization.public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :not_found
  end

  test "cannot update another client's organization" do
    bootstrap_and_select!(@user, @token)
    other_organization = bootstrap_other_client.collective

    patch acme_app_organization_url(other_organization.public_id, ri: "jp", host: @host),
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

# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("BASE_SERVICE_URL", "www.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    @bootstrap = bootstrap_and_select!(@user, @token)
  end

  test "index lists organizations" do
    get base_app_organizations_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_select "body", text: /organization/i
  end

  test "show resolves by public_id" do
    get base_app_organization_url(@bootstrap.collective.public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_select "body", text: /organization/i
  end

  test "unknown public_id returns 404" do
    get base_app_organization_url("unknown-organization", ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :not_found
  end

  private

  def bootstrap_and_select!(user, token)
    result = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    BaseSelectorAuthority.prepare(surface: :app, principal: user, session: token)
    result
  end
end

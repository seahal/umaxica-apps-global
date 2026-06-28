# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::GroupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_service)
    @acme_host = configured_host(:acme_service)
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
  end

  test "index renders groups" do
    get base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_select "body", text: /groups/i
  end

  test "unauthenticated cannot access groups" do
    get base_app_groups_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :redirect
    assert_oidc_authorize_redirect(response.location, host: @acme_host)
  end
end

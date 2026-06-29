# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Base::App::GroupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_service)
    @acme_host = configured_host(:acme_service)
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
  end

  test "index renders groups through inertia" do
    get base_app_groups_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_includes response.body, 'data-theme="system"'
    assert_includes response.body, 'class="theme-system"'
    assert_select "html[lang=?]", "ja"
    assert_select "title", /Groups/
    assert_select "script[data-page='app'][type='application/json']"
    assert_includes response.body, '"component":"base/app/groups/index"'
    assert_includes response.body, "entrypoints/inertia"
  end

  test "unauthenticated cannot access groups" do
    get base_app_groups_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :redirect
    assert_oidc_authorize_redirect(response.location, host: @acme_host)
  end
end

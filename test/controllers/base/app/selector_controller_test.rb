# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::SelectorControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("BASE_SERVICE_URL", "www.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "unauthenticated identity cannot access selector" do
    get base_app_selector_url(host: @host), headers: host_headers(@host), as: :json

    assert_response :unauthorized
  end

  test "authenticated identity without selected actor context can access selector" do
    get base_app_selector_url(host: @host), headers: as_user_headers(@user, host: @host), as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal "selected", body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "freshly provisioned identity auto-selects on the first selector request" do
    IdentityGraphProvisioner.call!(surface: :app, principal: @user)

    get base_app_selector_url(host: @host), headers: as_user_headers(@user, host: @host), as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
    assert_equal 1, ClientIdentity.where(source_record_id: @user.id).count
  end

  test "html selector request redirects after preparing a single selected context" do
    get base_app_selector_url(host: @host, ri: "jp"),
        headers: as_user_headers(@user, host: @host, session_public_id: @token.public_id)

    assert_redirected_to base_app_dashboard_path(ri: "jp")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "selector update persists valid selected actor context" do
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    candidate = BaseSelectorAuthority.new(
      surface: :app, principal: @user,
      session: @token,
    ).selectable_candidates.first

    patch base_app_selector_url(host: @host),
          params: candidate[:public],
          headers: as_user_headers(@user, host: @host, session_public_id: @token.public_id),
          as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")
    assert_equal candidate[:public][:account_public_id], @token.reload.selected_account_public_id
  end

  test "selector update renders invalid selection error as json" do
    BaseSelectorAuthority.stub(:select, ->(*) { raise BaseSelectorAuthority::InvalidSelection, "bad" }) do
      patch base_app_selector_url(host: @host),
            params: { account_public_id: "invalid" },
            headers: as_user_headers(@user, host: @host, session_public_id: @token.public_id),
            as: :json
    end

    assert_response :unprocessable_content
    assert_equal "invalid_selection", response.parsed_body.fetch("status")
  end
end

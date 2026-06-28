# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::WelcomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("BASE_SERVICE_URL")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "welcome sequence redirects to the configured after welcome path" do
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)

    get base_app_welcome_entry_url(ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host, session_public_id: @token.public_id)

    assert_redirected_to base_app_dashboard_path(ri: "jp")
  end
end

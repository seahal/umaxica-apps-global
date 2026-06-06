# typed: false
# frozen_string_literal: true

require "test_helper"

class SignSelectorBoundaryTest < ActionDispatch::IntegrationTest
  test "sign selector handoff does not create acme account organization or avatar" do
    host = ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")
    user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    assert_no_difference -> { ClientAccount.count + ClientIdentity.count + Persona.count + Enterprise.count + Avatar.count } do
      get sign_app_selector_url(host: host), headers: as_user_headers(user, host: host, session_public_id: token.public_id)
    end

    assert_response :redirect
    assert_nil token.reload.selected_account_public_id
  end
end

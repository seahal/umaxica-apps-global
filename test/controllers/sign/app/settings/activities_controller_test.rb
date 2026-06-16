# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Settings::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = clients(:one)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    host! @host
  end

  test "sign settings activities redirects to acme authority" do
    get sign_app_settings_activities_url(ri: "jp"), headers: session_headers

    assert_redirected_to acme_app_settings_activities_url(ri: "jp", host: @acme_host)
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end
end

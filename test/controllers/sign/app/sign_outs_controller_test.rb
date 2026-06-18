# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::SignOutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_statuses, :client_token_kinds

  test "sign app sign-out ceremony routes are retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("ID_SERVICE_URL", "id.app.localhost")}/sign/out/confirmation",
        method: :get,
      )
    end
  end

  test "signed-out page renders without revoking current token" do
    user = clients(:one)
    token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get sign_app_sign_out_url(ri: "jp", host: ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")),
        headers: {
          "X-TEST-CURRENT-USER" => user.id.to_s,
          "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
        }

    assert_response :success
    assert_select "a[href=?]", sign_app_sign_in_path(ri: "jp")
    assert_predicate token.reload, :currently_usable?
  end
end

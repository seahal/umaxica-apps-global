# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Sign::Up::Check::Google::BirthdatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host
    cookies["csrf_token"] = csrf_token_value
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "update does not redirect signed-in clients away from the google birthdate checkpoint" do
    user = clients(:one)

    patch sign_app_sign_up_check_google_birthdate_url(ri: "jp"),
          headers: as_user_headers(user, host: @host)

    assert_response :unprocessable_content
    assert_includes response.body, "ticket is required"
  end
end

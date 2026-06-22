# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::Sign::Up::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses

  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
  end

  test "completion route is post only" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{@host}/sign/up/email/completion", method: :get)
    end

    recognized = Rails.application.routes.recognize_path("https://#{@host}/sign/up/email/completion", method: :post)

    assert_equal "acme/app/sign/up/emails", recognized[:controller]
    assert_equal "completion", recognized[:action]
  end

  test "completion without a sign-up ticket is rejected" do
    host! @host

    post completion_acme_app_sign_up_email_url(ri: "jp", host: @host),
         headers: { "Host" => @host }

    assert_response :unprocessable_content
    assert_includes response.body, "ticket is required"
  end
end

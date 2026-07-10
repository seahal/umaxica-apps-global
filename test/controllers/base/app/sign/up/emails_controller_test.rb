# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseAppSignUpEmailCompletionRouteTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
  end

  test "email sign-up completion route no longer exists" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{@host}/sign/up/email/completion", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{@host}/sign/up/email/completion", method: :post)
    end
  end
end
